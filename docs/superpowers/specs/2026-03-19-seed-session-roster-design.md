# Seed Session Roster on Creation — Design Spec

**Issue:** [#471](https://github.com/MaxPayne89/klass-hero/issues/471)
**Date:** 2026-03-19
**Status:** Approved

## Problem

When a provider creates a session for a program, enrolled children do not appear in the session roster. The `CreateSession` use case persists the session and fires a `session_created` event, but no handler reacts by seeding participation records for enrolled children. The roster page (`ParticipationLive`) reads existing `participation_records` via `list_by_session/1`, so it always shows empty.

## Solution: Async Integration Event Subscriber

React to the `session_created` integration event (already published to PubSub by `PromoteIntegrationEvents`) with a new subscriber in the Participation context. The subscriber queries the Enrollment context via an ACL for active enrollments, then bulk-creates participation records.

### Event Flow

```
CreateSession.execute/1
  → session_created domain event
  → PromoteIntegrationEvents handler
  → PubSub topic "integration:participation:session_created"
  → SeedSessionRosterSubscriber (GenServer)
  → SeedSessionRoster use case
  → EnrollmentContextACL → Enrollment.list_program_enrollments/1
  → bulk insert participation_records (ON CONFLICT DO NOTHING)
  → roster_seeded domain event
  → NotifyLiveViews → PubSub → ParticipationLive reloads roster
```

### Why Async (Integration Event) Over Sync (Domain Event Handler)

Eventual consistency is acceptable — LiveView streams roster updates in real-time via PubSub, so the provider sees records appear without a manual refresh. The async approach keeps `CreateSession` focused on its single responsibility and sets up the pattern for future #481 (late enrollment → session seeding).

## New Components

### 1. Port: `ForResolvingEnrolledChildren`

**Location:** `lib/klass_hero/participation/domain/ports/for_resolving_enrolled_children.ex`

Behaviour contract:

```elixir
@callback list_enrolled_child_ids(program_id :: String.t()) :: [String.t()]
```

Returns child IDs only — name resolution happens later via the existing `ChildInfoResolver` in `GetSessionWithRoster`.

### 2. ACL Adapter: `EnrollmentContext.EnrolledChildrenResolver`

**Location:** `lib/klass_hero/participation/adapters/driven/enrollment_context/enrolled_children_resolver.ex`

Calls `Enrollment.list_program_enrollments/1` and plucks `child_id` from the enriched result maps. Slight over-fetching but avoids any changes to the Enrollment context.

### 3. Use Case: `SeedSessionRoster`

**Location:** `lib/klass_hero/participation/application/use_cases/seed_session_roster.ex`

**Input:** `session_id`, `program_id`

**Logic:**

1. Query enrolled child IDs via the ACL port
2. Build `ParticipationRecord` structs with status `:registered`
3. Bulk insert with ON CONFLICT DO NOTHING on `(session_id, child_id)` unique constraint
4. Log: count seeded, count skipped (duplicates)
5. Publish `roster_seeded` domain event for LiveView notification

**Capacity decision:** `max_capacity` is intentionally NOT enforced during seeding. All enrolled children get registered regardless. Capacity is a scheduling/enrollment concern, not a roster gate. This decision must be documented with an explanatory comment in the use case.

**Error handling:** Best-effort. ACL failures or insert errors are logged but swallowed — session creation is already complete. Follows the `publish_best_effort` pattern established in `PromoteIntegrationEvents`.

### 4. Subscriber: `SeedSessionRosterSubscriber`

**Location:** `lib/klass_hero/participation/adapters/driven/events/subscribers/seed_session_roster_subscriber.ex`

GenServer started under the application supervision tree.

- `init/1`: subscribes to `"integration:participation:session_created"`
- `handle_info({:integration_event, event}, state)`: extracts `program_id` and `session_id` from payload, delegates to `SeedSessionRoster.execute/2`
- Stateless — no GenServer state beyond the subscription

Not using Oban for durable delivery: if the node is down, the session creation that fired the event also didn't happen. Can be promoted to critical event later if needed.

### 5. Domain Event: `roster_seeded`

New event in `ParticipationEvents` — published after bulk insert completes. Flows through the existing `NotifyLiveViews` handler to push updates to `ParticipationLive` via the provider-specific PubSub topic.

Handles the eventual consistency gap: if the provider navigates to "manage participants" before seeding completes, they see empty state briefly, then records stream in automatically.

## Configuration

Wire the new port/adapter in `config/config.exs` under the `:participation` key:

```elixir
enrolled_children_resolver:
  KlassHero.Participation.Adapters.Driven.EnrollmentContext.EnrolledChildrenResolver
```

Test config swaps to a mock via `config/test.exs`.

Add `SeedSessionRosterSubscriber` to the application supervision tree children in `application.ex`.

## What This Does NOT Do

- **Late enrollments** — children enrolling after session creation are not auto-added to existing sessions. Tracked in [#481](https://github.com/MaxPayne89/klass-hero/issues/481).
- **Enrollment cancellation** — cancelled enrollments do not remove participation records from future sessions. Separate concern.
- **Capacity enforcement** — `max_capacity` is not checked during roster seeding.

## Testing

### Unit: SeedSessionRoster use case

- Mock ACL returns known child IDs → verify records created with `:registered` status
- Run twice → verify idempotency (no duplicates via ON CONFLICT)
- Empty enrollments → no records, no crash

### Unit: SeedSessionRosterSubscriber

- Receives `{:integration_event, ...}` with session_created → delegates to use case
- Ignores malformed or irrelevant messages

### Unit: EnrolledChildrenResolver ACL

- Verify child IDs plucked correctly from `Enrollment.list_program_enrollments/1` results
- Empty program → empty list

### Integration: end-to-end

- Create program with enrolled children → create session → assert participation records appear
- Use async assertion pattern to handle the PubSub delivery gap

## Migration

No migration needed. The `participation_records` table already has all required columns (`session_id`, `child_id`, `status`) and the `(session_id, child_id)` unique constraint for ON CONFLICT handling.
