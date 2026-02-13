# Bounded Context Restructuring

## Problem

The current bounded context boundaries have naming and cohesion issues:

1. **Identity is a junk drawer.** It owns parent profiles, provider profiles, children, consents, staff members, verification documents, and referral codes. These serve different actors (parents vs providers vs admins) with zero shared domain logic between them. The name "Identity" gives no clue about half its responsibilities.

2. **Community is dead code.** No route in the router, in-memory repository only, pure prototype. Occupies namespace and directory structure for nothing.

3. **Support is over-architected.** A full bounded context (ports, adapters, use cases, domain models) for a single contact form submission. ~10 lines of actual domain logic wrapped in DDD ceremony.

## Decisions

### 1. Split Identity -> Family + Provider

Identity currently serves three distinct actors with zero shared domain logic. Split it into two cohesive contexts.

#### Family (from Identity)

**What moves here:** Parent profiles, children, consents, referral codes.

**Why:** These are a cohesive unit. A parent manages their children. Consents are granted *for* family members. Referral codes are used by parents. The aggregate root is the family relationship.

**What Family owns:**
- `ParentProfile` - parent account with subscription tier
- `Child` - child info (name, DOB, emergency contact, support needs, allergies)
- `Consent` - child consent records
- `ReferralCodeGenerator` - generates referral codes for parents

**Ports carried over:**
- `ForStoringParentProfiles`
- `ForStoringChildren`
- `ForStoringConsents`

#### Provider (from Identity)

**What moves here:** Provider profiles, verification documents, staff members.

**Why:** Providers have distinct needs from parents - business profiles, verification workflows (admin-facing), staff management. These all orbit the same aggregate: a provider running their business. The connection to ProgramCatalog is strong (providers create programs), but the differences in actor, workflow complexity, and rate of change warrant separate contexts.

**What Provider owns:**
- `ProviderProfile` - business provider with verification status, referral code
- `VerificationDocument` - provider verification with admin review workflow
- `StaffMember` - provider's staff with active flag

**Ports carried over:**
- `ForStoringProviderProfiles`
- `ForStoringVerificationDocuments`
- `ForStoringStaffMembers`

### 2. Remove Community context entirely

Community has no router route, uses an in-memory repository, and is a prototype that never shipped. Remove all files:
- `lib/klass_hero/community/` (entire directory)
- `lib/klass_hero_web/live/community_live.ex`
- `test/klass_hero/community/` (entire directory)
- References in `config/config.exs`, `application.ex`, `klass_hero_web.ex`

### 3. Strip Support context, keep ContactLive working

The contact page at `/contact` is live and routed. Inline the domain logic:
- Keep `ContactLive` and its route
- Create `KlassHeroWeb.Schemas.ContactForm` as a simple embedded schema with changeset validations
- `ContactLive` calls `Repo.insert` directly - no ports & adapters needed
- Remove the full DDD structure: `lib/klass_hero/support/` directory, `lib/klass_hero/support.ex` facade
- Remove references in `config/config.exs`, `application.ex`, `klass_hero_web.ex`

## Resulting Context Map

```
Accounts        (unchanged)       Auth, sessions, tokens, GDPR
Family          (from Identity)   Parent profiles, children, consents, referral codes
Provider        (from Identity)   Provider profiles, verification, staff
ProgramCatalog  (unchanged)       Programs, instructors, categories, pricing
Enrollment      (unchanged)       Bookings, fees, entitlements
Messaging       (unchanged)       Conversations, messages, broadcasts
Participation   (unchanged)       Sessions, check-in/out, attendance, behavioral notes
Shared          (unchanged)       Events, config, infrastructure
```

**Removed:** Community (dead code), Support (over-architected, inlined into ContactLive)

## Cross-Context Dependencies (updated)

- **Enrollment** -> ProgramCatalog (program pricing), Family (subscription tiers)
- **Messaging** -> Enrollment (broadcast recipients), ProgramCatalog (retention policy)
- **Participation** -> Family (child name resolution)
- **GDPR cascade:** Accounts -> Family + Provider + Participation + Messaging

## Known Coupling: ParentProfileSchema Join

Enrollment's repository directly joins against `ParentProfileSchema` for subscription tier lookups:

```elixir
# enrollment_repository.ex
|> join(:inner, [e], p in ParentProfileSchema, on: e.parent_id == p.id)
```

Identity currently exports this schema explicitly for Enrollment. After the split, Family must export `ParentProfileSchema` and Enrollment must declare a Boundary dependency on `KlassHero.Family`. This is tighter coupling than a port-based dependency — a schema-level join rather than a function call. Flagged as a known tradeoff; acceptable for now but worth revisiting if the join query needs to grow.

## Event Infrastructure Changes

### user_registered Handler Split

The current `IdentityEventHandler` handles `user_registered` and creates both parent and provider profiles in a single handler with combined error reporting. After the split:

- **Family** gets its own `FamilyEventHandler` subscribing to `integration:accounts:user_registered` and `integration:accounts:user_anonymized`
- **Provider** gets its own `ProviderEventHandler` subscribing to the same two topics
- Each handler independently creates its respective profile on `user_registered`
- The current combined error reporting (`combine_results/1`) is no longer needed — each handler reports its own errors independently
- A user registering with both roles triggers both handlers independently; this is correct behavior

### Integration Event Topic Renames

Current topics and their replacements:

| Current Topic | New Topic | Subscriber |
|---|---|---|
| `integration:accounts:user_registered` | (unchanged) | Family, Provider (both subscribe) |
| `integration:accounts:user_anonymized` | (unchanged) | Family, Provider, Messaging (all subscribe) |
| `integration:identity:child_data_anonymized` | `integration:family:child_data_anonymized` | Participation |

The `IdentityIntegrationEvents` module's `@source_context` changes from `:identity` to `:family` in the new `FamilyIntegrationEvents` module.

### GDPR Cascade (precise flow)

```
Accounts publishes: user_anonymized
  -> Family subscribes:
       - Deletes consent records for each child
       - Anonymizes child PII
       - Dispatches child_data_anonymized domain event per child
       - Promotes to integration:family:child_data_anonymized
         -> Participation subscribes: anonymizes behavioral notes for child
  -> Provider subscribes:
       - Anonymizes provider profile data (if user has provider role)
  -> Messaging subscribes:
       - Anonymizes messages, marks participant as left
       - Dispatches user_data_anonymized domain event
```

### DomainEventBus Configuration (application.ex)

Current single Identity bus splits into two:

```elixir
# Family DomainEventBus
context: KlassHero.Family,
handlers: [
  {:child_data_anonymized,
   {KlassHero.Family.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents, :handle},
   priority: 10}
]

# Provider DomainEventBus
context: KlassHero.Provider,
handlers: []  # No domain events to promote currently
```

### Integration Event Subscribers (application.ex)

Current single Identity subscriber splits into two:

```elixir
# Family subscriber
handler: KlassHero.Family.Adapters.Driven.Events.FamilyEventHandler,
topics: ["integration:accounts:user_registered", "integration:accounts:user_anonymized"]

# Provider subscriber
handler: KlassHero.Provider.Adapters.Driven.Events.ProviderEventHandler,
topics: ["integration:accounts:user_registered", "integration:accounts:user_anonymized"]

# Participation subscriber (topic rename)
handler: KlassHero.Participation.Adapters.Driven.Events.ParticipationEventHandler,
topics: ["integration:family:child_data_anonymized"]  # was integration:identity:*
```

## Boundary Configuration

Both new contexts need `use Boundary` declarations:

```elixir
# lib/klass_hero/family.ex
use Boundary,
  top_level?: true,
  deps: [KlassHero, KlassHero.Shared],
  exports: [
    Domain.Models.Child,
    Domain.Models.ParentProfile,
    Domain.Models.Consent,
    Adapters.Driven.Persistence.ChangeChild,
    # Exported for Enrollment's parent_profile join query
    Adapters.Driven.Persistence.Schemas.ParentProfileSchema
  ]

# lib/klass_hero/provider.ex
use Boundary,
  top_level?: true,
  deps: [KlassHero, KlassHero.Shared],
  exports: [
    Domain.Models.ProviderProfile,
    Domain.Models.StaffMember,
    Domain.Models.VerificationDocument,
    Adapters.Driven.Persistence.ChangeProviderProfile,
    Adapters.Driven.Persistence.ChangeStaffMember
  ]
```

Contexts that currently depend on `KlassHero.Identity` must update:
- `KlassHero.Enrollment` -> deps: `[..., KlassHero.Family]` (for ParentProfileSchema)
- `KlassHero.Participation` -> deps: `[..., KlassHero.Family]` (for child info resolution)
- `KlassHero.Application` -> deps: replace `KlassHero.Identity` with `KlassHero.Family, KlassHero.Provider`
- `KlassHeroWeb` -> deps: replace `KlassHero.Identity` with `KlassHero.Family, KlassHero.Provider`

## Migration Strategy

This is a large refactor touching many files. Suggested execution order:

1. **Remove Community** - pure deletion, no dependencies, quick win
2. **Inline Support** - strip context, create `KlassHeroWeb.Schemas.ContactForm`, keep ContactLive working
3. **Split Identity -> Family + Provider** - the big one
   - Create Family context with parent/child/consent modules
   - Create Provider context with provider/verification/staff modules
   - Split event handlers and subscribers
   - Update integration event topics (`identity:` -> `family:`)
   - Update Boundary declarations and deps
   - Update all web layer references
   - Update config/config.exs repository bindings
   - Update tests
4. **Update documentation** - CLAUDE.md, DDD_ARCHITECTURE.md, technical-architecture.md

Each step must compile with `--warnings-as-errors` and pass all tests before moving to the next.

## Open Questions

None - all decisions resolved in discussion.
