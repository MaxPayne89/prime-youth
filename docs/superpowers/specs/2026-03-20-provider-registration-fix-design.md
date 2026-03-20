# Fix: Provider Registration Creates Family Account Instead (#484)

## Problem

When a user registers as a provider with a subscription tier, they return after email
confirmation as a family/parent account. Two root causes:

1. **Tier data loss** — `provider_subscription_tier` is a virtual field on the User schema.
   After `Repo.insert`, the value is `nil`, so the domain event payload never carries the
   selected tier to the `ProviderEventHandler`.

2. **No compensation for async profile creation** — Profile creation happens asynchronously
   via PubSub (domain event → integration event → EventSubscriber → handler). If this chain
   is delayed or fails, `Scope.resolve_roles` finds no profiles at login time. There is no
   second chance — `user_confirmed` is not promoted to an integration event.

## Approach

Saga choreography with eventual consistency. Fix the data flow and add a compensation
event, rather than collapsing the async model.

## Design

### 1. Persist `provider_subscription_tier`

**Migration:** Add a nullable `provider_subscription_tier` string column to the `users` table.
Only relevant for users with `:provider` in `intended_roles`.

**Schema change:** Remove `virtual: true` from the field definition in
`lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex:36`.

The `registration_changeset` already casts and validates this field — no changeset changes needed.

**Effect:** After `Repo.insert`, `user.provider_subscription_tier` retains the selected value.
`UserEvents.user_registered/3` (which reads `Map.get(user, :provider_subscription_tier)`)
now gets the real value instead of `nil`.

### 2. Promote `user_confirmed` to an integration event

Currently `user_confirmed` is a domain event only. Four changes:

#### 2a. Enrich `user_confirmed` domain event payload

`UserEvents.user_confirmed/3` currently only includes `email` and `confirmed_at`. Add
`name`, `intended_roles`, and `provider_subscription_tier` so the integration event carries
everything downstream handlers need without cross-context queries.

`name` is required because the `ProviderEventHandler` uses it as `business_name` when
creating a provider profile. If `user_confirmed` is the compensation path that first
creates the profile, it must have `name` available.

The factory needs to accept a user struct with these fields loaded (all are persisted).

#### 2b. `AccountsIntegrationEvents.user_confirmed/3`

New factory function creating an integration event with payload:
- `user_id` (from aggregate_id)
- `name`
- `intended_roles`
- `provider_subscription_tier`
- `email`, `confirmed_at`

Marked `:critical` — profile creation is a business-critical side effect.

**Note on Oban fallback:** The `:critical` flag provides idempotent deduplication via
`CriticalEventDispatcher` on the PubSub path. Full Oban durable-retry for
`user_confirmed` (via `critical_event_handlers` config) is a pre-existing gap shared
with `user_registered` and is deferred to a separate follow-up.

#### 2c. `PromoteIntegrationEvents` — handle `user_confirmed`

New `handle/1` clause for `:user_confirmed` that promotes via
`AccountsIntegrationEvents.user_confirmed/3`. Same pattern as existing
`user_registered` and `user_anonymized` clauses.

#### 2d. Register on Accounts DomainEventBus

Add `{:user_confirmed, {PromoteIntegrationEvents, :handle}, priority: 10}` to the
handlers list in `application.ex`.

### 3. Downstream handlers subscribe to `user_confirmed`

#### ProviderEventHandler

- Add `:user_confirmed` to `subscribed_events`
- New `handle_event/1` clause for `:user_confirmed`:
  1. Read `intended_roles` and `provider_subscription_tier` from payload
  2. If `"provider" in intended_roles` — call same `create_provider_profile_with_retry/3`
  3. Existing retry helper handles duplicate identity → `:ok` (idempotent)

Happy path: `user_registered` already created the profile, `user_confirmed` tries again,
gets a duplicate → `:ok`.

Compensation path: `user_registered` delivery was delayed or failed, `user_confirmed`
creates the profile just in time.

#### FamilyEventHandler

- Add `:user_confirmed` to `subscribed_events`
- New clause checks `"parent" in intended_roles`, calls `create_parent_profile_with_retry/1`
- Same idempotency guarantee via duplicate identity handling

#### EventSubscriber registration

Both subscribers in `application.ex` need `"integration:accounts:user_confirmed"` added
to their topics list.

### 4. Post-confirmation routing (out of scope)

`signed_in_path/1` always returns `/users/settings`. Provider-aware routing is tracked
separately in #485.

## Testing

### Unit tests

- `UserEvents.user_confirmed/3` — enriched payload includes `name`, `intended_roles`,
  and `provider_subscription_tier`
- `AccountsIntegrationEvents.user_confirmed/3` — correct payload, criticality `:critical`
- `ProviderEventHandler` — `:user_confirmed` clause creates profile when missing, returns
  `:ok` when profile exists (idempotency)
- `FamilyEventHandler` — same pattern for parent profiles

### Integration tests

- Full registration → confirmation flow: register as provider with tier → confirm email →
  verify provider profile exists with correct tier
- Idempotency: both `user_registered` and `user_confirmed` fire → only one profile exists

### No changes to existing tests

The `user_registered` path is unchanged. New event path is additive.

## Files affected

| File | Change |
|------|--------|
| New migration | Add `provider_subscription_tier` column to `users` |
| `accounts/.../schemas/user.ex` | Remove `virtual: true` from field |
| `accounts/domain/events/user_events.ex` | Enrich `user_confirmed` payload |
| `accounts/domain/events/accounts_integration_events.ex` | Add `user_confirmed/3` factory |
| `accounts/.../event_handlers/promote_integration_events.ex` | Add `:user_confirmed` clause |
| `application.ex` | Register `:user_confirmed` on Accounts bus; add PubSub topic to Provider/Family subscribers |
| `provider/.../events/provider_event_handler.ex` | Subscribe to `:user_confirmed`, add handler clause |
| `family/.../events/family_event_handler.ex` | Subscribe to `:user_confirmed`, add handler clause |
| Test files | Unit + integration tests for new event path |
