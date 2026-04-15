# Provider Session Counter — Design Spec

**Issue:** #372 — [FEATURE] Add Session Counter to Provider Overview Dashboard
**Date:** 2026-04-15
**Approach:** Event-driven projection (CQRS read model)

## Summary

Add a `ProviderSessionStats` projection that tracks completed session counts per (provider, program). The projection subscribes to `session_completed` integration events from the Participation context, maintains a denormalized read table, and surfaces the count on the Provider Overview Dashboard.

As a prerequisite, refactor the `ProjectionSupervisor` to use `:one_for_one` strategy so all projections (including this new one) are independently supervised.

## Data Model

### New table: `provider_session_stats`

| Column                     | Type               | Notes                                      |
| -------------------------- | ------------------ | ------------------------------------------ |
| `id`                       | `binary_id`        | PK                                         |
| `provider_id`              | `binary_id`        | Not a DB-level FK (read model)             |
| `program_id`               | `binary_id`        | Not a DB-level FK (read model)             |
| `program_title`            | `string`           | Denormalized for display                   |
| `sessions_completed_count` | `integer`          | Default 0                                  |
| `inserted_at`              | `utc_datetime_usec`|                                            |
| `updated_at`               | `utc_datetime_usec`|                                            |

- Unique index on `(provider_id, program_id)` — upsert key.

### Read model DTO

`Provider.Domain.ReadModels.SessionStats` — lightweight struct matching the table columns. No business logic.

## Projection GenServer

**Module:** `Provider.Adapters.Driven.Projections.ProviderSessionStats`

### Lifecycle

1. `init/1` — subscribes to `integration:participation:session_completed` via PubSub (subscribe-before-bootstrap pattern).
2. Bootstraps by computing current counts from Participation source data via ACL.
3. Live events arrive via `handle_info({:integration_event, event})`.

### Live event handling

On `session_completed`:

1. Extract `provider_id`, `program_id`, `program_title` from event payload.
2. Upsert into `provider_session_stats`:
   - `ON CONFLICT (provider_id, program_id) DO UPDATE SET sessions_completed_count = sessions_completed_count + 1, program_title = EXCLUDED.program_title, updated_at = EXCLUDED.updated_at`
   - Uses SQL-level atomic increment to avoid race conditions.
3. Publish to `provider:#{provider_id}:stats_updated` PubSub topic for real-time dashboard refresh.

### Counter accuracy strategy

Bootstrap computes the full accurate count from source. Live events increment atomically from there. On crash/restart, the supervisor triggers a fresh bootstrap that recomputes from source, then live events resume.

## Event Enrichment

The `session_completed` integration event in the Participation context currently carries `session_id` and `program_id`. This design adds `provider_id` and `program_title` to the payload.

**Change location:** `ParticipationIntegrationEvents.session_completed/1` builder function (defines the payload shape). The `PromoteIntegrationEvents` handler passes through whatever the builder produces — no changes needed there.

**Source:** Participation already has a `ProgramProviderResolver` ACL that resolves `program_id -> provider_id`. Program title can be resolved from the same source or from the session's associated program.

## Bootstrap & ACL

### New port

`Provider.Domain.Ports.ForResolvingSessionStats` — behaviour with:

```elixir
@callback list_completed_session_counts() :: {:ok, [map()]} | {:error, term()}
```

Returns a list of `%{provider_id, program_id, program_title, sessions_completed_count}`.

### New ACL adapter

`Provider.Adapters.Driven.ACL.ParticipationSessionStatsACL`

Cross-context bootstrap query (acceptable for one-time startup):
- Queries Participation's `sessions` table for completed sessions, grouped by `program_id`.
- Joins Program Catalog's `programs` table to resolve `provider_id` and `program_title` for each program.

### Bootstrap flow

1. Call ACL via DI-wired port.
2. Bulk upsert all rows with `insert_all` + `on_conflict: :replace_all_except [:id, :inserted_at]`.
3. Retry up to 3 times with exponential backoff on failure.

## Read Repository

**Module:** `Provider.Adapters.Driven.Persistence.Repositories.SessionStatsRepository`

**Port:** `Provider.Domain.Ports.ForQueryingSessionStats`

Callbacks:
- `list_for_provider(provider_id)` — returns `[SessionStats.t()]` ordered by `sessions_completed_count DESC`.
- `get_total_count(provider_id)` — returns `non_neg_integer()` (SUM of all counts).

## Dashboard Integration

**File:** `lib/klass_hero_web/live/provider/dashboard_live.ex`

### On mount / handle_params for `:overview` tab

1. Query read repo for total session count via `get_total_count/1`.
2. Subscribe to `provider:#{provider_id}:stats_updated` PubSub topic.

### On `handle_info` for stats update

1. Re-query and re-assign the count.

### Template

Render session count in one of the existing (currently commented-out) stats card slots in the overview section.

Per-program breakdown is available in the data but not surfaced in this iteration.

## Supervision Tree Refactor

### Change

Switch `ProjectionSupervisor` strategy from `:rest_for_one` to `:one_for_one`. Each projection crashes and restarts independently.

### Caveat

`ProgramListings` calls `VerifiedProviders.verified?/1` during bootstrap. Under `:one_for_one`, if `VerifiedProviders` is down, that call may fail. The existing retry logic (3 attempts with backoff) should cover this, but verify during implementation. A `Process.whereis` guard is available as fallback.

### New child

Add `ProviderSessionStats` GenServer to the supervision tree. Order does not matter under `:one_for_one`.

## Testing Strategy

### Unit tests

1. **Projection GenServer** — handling `session_completed` event upserts correct row. Replay idempotency: bootstrap + event produces correct count (no double-counting).
2. **ACL adapter** — bootstrap query correctly counts completed sessions grouped by `(provider_id, program_id)`.
3. **Read repository** — `list_for_provider/1` returns DTOs ordered by count DESC; `get_total_count/1` sums correctly.
4. **Event enrichment** — `session_completed` integration event includes `provider_id` in payload.

### Integration tests

5. **Dashboard LiveView** — overview section renders session count.
6. **Acceptance criteria:**
   - Session count increments on attendance completion.
   - Manual check-in without completing does NOT increment (verify `check_in` events don't trigger projection).
   - Count tied to specific provider and program (test with multiple providers/programs, verify isolation).

## Acceptance Criteria Mapping

| Criterion | Mechanism |
| --- | --- |
| Count increments on attendance completion | Projection handles `session_completed` event, atomic increment |
| Manual check-in without completion does not increment | Only `session_completed` events trigger the projection, not `check_in` |
| Count tied to specific provider and program | Unique index on `(provider_id, program_id)`, per-row isolation |
