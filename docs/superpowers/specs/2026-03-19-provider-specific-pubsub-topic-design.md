# Provider-Specific PubSub Topic Routing — Design Spec

**Issue:** #464
**Date:** 2026-03-19
**Status:** Approved

## Problem

SessionsLive subscribes to generic event topics (`participation:session_created`, etc.) and filters by `provider_program_ids` client-side. This leaks domain logic into the LiveView and sends irrelevant events to every connected provider.

## Goal

Add provider-specific topic routing so SessionsLive subscribes to `participation:provider:#{provider_id}` and receives only relevant events. Eliminate client-side filtering.

## Approach

ACL-based resolution now; projection-based cache as a documented follow-up.

### Out of Scope

- Projection/ETS cache for `program_id → provider_id` (follow-up issue)
- Changes to other LiveView subscribers (`ParticipationLive`, `ParticipationHistoryLive`)

## 1. ACL Port & Adapter

### Port

New behaviour: `Participation.Domain.Ports.ForResolvingProgramProvider`

```elixir
@callback resolve_provider_id(program_id :: binary()) ::
            {:ok, binary()} | {:error, :program_not_found}
```

Single function — only `provider_id` is needed. No batch variant; events arrive one at a time.

### Adapter

New module: `Participation.Adapters.Driven.ProgramCatalogContext.ProgramProviderResolver`

- Calls `ProgramCatalog.get_programs_by_ids([program_id])`
- Extracts `provider_id` from result
- Maps `:not_found` → `:program_not_found` per ACL error-mapping convention

### Config

New key `program_provider_resolver` under `:participation` in `config.exs` and `test.exs`, pointing to the adapter module.

## 2. Event Payload Enrichment

### Problem

`child_checked_in`, `child_checked_out`, and `child_marked_absent` event payloads only carry `session_id` — no `program_id`. The handler needs `program_id` to resolve `provider_id`.

### Solution

Change event factory signatures in `ParticipationEvents` to accept the session as a second argument:

- `child_checked_in(record, session)` — adds `program_id: session.program_id` to payload
- `child_checked_out(record, session)` — same
- `child_marked_absent(record, session)` — same

The existing `/1` arity variants remain for backward compatibility during transition, but the use cases switch to `/2`.

### Use Case Helper

`Shared.run_attendance_action` already works with the record repository. It will additionally fetch the session (via session repository) and pass it to the event factory.

## 3. NotifyLiveViews Handler

### Current State

`Participation.NotifyLiveViews` delegates to `Shared.NotifyLiveViews`, which publishes to generic topics like `participation:session_created`.

### New Behavior

Replace the delegation with logic that:

1. Publishes to the **generic topic** (unchanged — `ParticipationLive`, `ParticipationHistoryLive` still need these)
2. Extracts `program_id` from the event payload
3. Resolves `provider_id` via the ACL port
4. Publishes to **provider-specific topic**: `participation:provider:#{provider_id}`

Uses `Shared.NotifyLiveViews.safe_publish/2` for both publishes (best-effort, swallows failures).

### Error Handling

If `provider_id` resolution fails (e.g., program not found), log a warning and skip the provider-specific publish. The generic topic publish still succeeds — no degradation for other subscribers.

## 4. SessionsLive Changes

### Subscriptions

Replace four generic topic subscriptions with one provider-specific subscription:

```elixir
Phoenix.PubSub.subscribe(KlassHero.PubSub, "participation:provider:#{provider_id}")
```

### handle_info Simplification

- Remove `MapSet.member?` guards on `provider_program_ids` — events are already scoped to this provider
- Remove `update_session_in_stream_if_owned` helper — no longer needed
- Keep the date check for `session_created` — still relevant to avoid inserting wrong-date sessions into the stream
- Keep `provider_program_ids` assign — still used for `save_session` authorization check (line 143)

## 5. Files Changed

| Layer | File | Change |
|-------|------|--------|
| Port | `participation/domain/ports/for_resolving_program_provider.ex` | New behaviour |
| Adapter | `participation/adapters/driven/program_catalog_context/program_provider_resolver.ex` | New — calls ProgramCatalog |
| Config | `config/config.exs`, `config/test.exs` | Wire `program_provider_resolver` key |
| Event factory | `participation/domain/events/participation_events.ex` | Add `/2` arities with session arg, include `program_id` |
| Use case helper | `participation/application/use_cases/shared.ex` | Fetch session, pass to event factory |
| Handler | `participation/adapters/driven/events/event_handlers/notify_live_views.ex` | Replace delegation — publish to both topics via ACL |
| LiveView | `klass_hero_web/live/provider/sessions_live.ex` | Subscribe to provider topic, simplify handle_info |
| Tests | New + updated | Port/adapter, handler, SessionsLive PubSub |

## 6. Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Provider ID resolution | ACL port (not domain model change) | Follows established pattern; no migration needed |
| Where resolution happens | Participation handler (not Shared) | Keeps Shared handler generic; mirrors PromoteIntegrationEvents pattern |
| child_checked_in program_id | Enrich payload via session arg | Avoids extra DB round-trip in handler; program_id is natural event context |
| Generic topics | Keep publishing | Other subscribers (ParticipationLive, ParticipationHistoryLive) depend on them |
| Future optimization | Follow-up issue for ETS projection | ACL query cost is negligible at current scale |
