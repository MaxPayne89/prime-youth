# Provider Create Session — Design Spec

**Issue:** #461
**Date:** 2026-03-18
**Status:** Approved

## Problem

The `CreateSession` use case exists in the Participation domain layer and is exposed via `Participation.create_session/1`, but the provider Sessions LiveView (`/provider/sessions`) has no UI for creating new sessions. Additionally, the existing PubSub real-time updates in SessionsLive are non-functional due to two pre-existing bugs.

## Scope

Three changes:

1. Fix PubSub bugs in SessionsLive (pre-existing)
2. Add "Create Session" modal form to SessionsLive
3. Handle `session_created` event for real-time stream update

### Out of scope

- Provider-specific PubSub topic routing (filed as follow-up issue)
- Program status filtering (no status field exists on Program model)

## 1. PubSub Bug Fixes

### Fix 1 — Topic Alignment

SessionsLive subscribes to `"participation:provider:#{provider_id}"`, but the event system publishes to generic topics like `"participation:session_started"`.

**Change:** Subscribe (inside `connected?` guard) to the four relevant generic event topics:
- `"participation:session_created"`
- `"participation:session_started"`
- `"participation:session_completed"`
- `"participation:child_checked_in"` (existing handler at line 107 needs this)

Filter relevance in `handle_info` by checking `event.payload.program_id` against the provider's program IDs.

**Note:** `child_checked_in` event payload does not include `program_id` (only `session_id`, `child_id`, etc.). For this event, skip the program_id filter and rely on the session fetch in `update_session_in_stream` — if the session doesn't belong to this provider, the fetch returns data for a session not in the current stream, which is harmless (stream_insert with an unknown ID is a no-op for the UI since it won't match the date filter). Alternatively, the handler can be a pass-through that re-fetches and verifies.

### Fix 2 — Message Format

SessionsLive's `handle_info` matches bare `%DomainEvent{}`, but `PubSubBroadcaster` sends `{:domain_event, %DomainEvent{}}`.

**Change:** Update all `handle_info` clauses to match `{:domain_event, %DomainEvent{...}}`.

### Fix 3 — Stream Data Shape

The existing `update_session_in_stream` does `{:ok, session} ->` from `get_session_with_roster/1`, but this function returns `{:ok, %{session: session, roster: roster}}`. The stream expects `ProgramSession.t()` structs (from `list_provider_sessions`). This is a latent bug — never triggered because PubSub handlers never fire.

**Change:** Destructure the result: `{:ok, %{session: session}} -> stream_insert(socket, :sessions, session)`.

### Follow-up

File a separate issue for migrating to provider-specific topic routing as an architectural improvement.

## 2. Create Session Form

### Routing

Add `:new` live action to the provider sessions route: `/provider/sessions/new`.

Add `handle_params/3` callback (does not currently exist) with `apply_action/3`:
- `:index` action — sets `show_modal: false`, clears form assigns
- `:new` action — sets `show_modal: true`, initializes form with defaults

### Mount Changes

Load provider programs in mount via `ProgramCatalog.list_programs_for_provider/1` (returns `[ProgramListing.t()]` read models — has `id`, `title`, `meeting_start_time`, `meeting_end_time`, `location` needed for dropdown and pre-fill). Store both the program list and a MapSet of program IDs (for PubSub filtering).

### Form Fields

| Field | Type | Default | Required |
|-------|------|---------|----------|
| `program_id` | dropdown (provider's programs) | — | yes |
| `session_date` | date picker | `@selected_date` | yes |
| `start_time` | time picker | pre-filled from program | yes |
| `end_time` | time picker | pre-filled from program | yes |
| `location` | text input | pre-filled from program | no |
| `notes` | textarea | — | no |
| `max_capacity` | number input | — | no |

### Pre-fill Behavior

When the provider selects a program, a `phx-change` event updates form defaults for `start_time`, `end_time`, and `location` from the selected program's `meeting_start_time`, `meeting_end_time`, and `location`. Provider can override any pre-filled value.

### Form Lifecycle

- Form built with `to_form/2` from a plain map (no Ecto changeset — `CreateSession` use case takes a params map)
- `phx-change="validate_session"` for live validation (time range, required fields)
- `phx-submit="save_session"` calls `Participation.create_session/1`
- On success: flash message, close modal via `push_patch` to `/provider/sessions` (does NOT touch the stream directly — the PubSub `session_created` handler inserts the session into the stream after `push_patch` processes)
- On error: display inline errors (`:invalid_time_range`, `:duplicate_session`, etc.)

### Type Coercion

HTML form params arrive as string-keyed maps with string values. The `CreateSession` use case expects atom keys with typed values (`Date.t()`, `Time.t()`, `pos_integer()`). The `save_session` handler must coerce params before calling the use case:

- `program_id` — string, pass through
- `session_date` — `Date.from_iso8601!/1`
- `start_time` / `end_time` — `Time.from_iso8601!/1` (HTML time inputs produce `"HH:MM"`, needs `":00"` appended for seconds)
- `max_capacity` — `String.to_integer/1` (only if non-empty)
- `location` / `notes` — strings, pass through (omit if empty)

### Security

Provider can only create sessions for their own programs. The dropdown only shows their programs, and `save_session` verifies `program_id` membership in the provider's program ID set before calling the use case.

## 3. Real-Time Stream Update

### session_created Event Handler

1. `save_session` calls `Participation.create_session/1`
2. Use case publishes `session_created` event to `"participation:session_created"`
3. `handle_info` receives `{:domain_event, %DomainEvent{event_type: :session_created}}`
4. Handler checks:
   - `event.payload.program_id` is in provider's program ID set
   - Session date matches `@selected_date`
5. If both pass: fetch full session via `Participation.get_session_with_roster/1`, insert into stream
6. If either fails: ignore (wrong provider or wrong day)

### Existing Event Handlers

The existing `session_started` and `session_completed` handlers also gain the provider program ID filter, plus the corrected topic subscription and message format from the bug fixes.

## Key Files

| File | Change |
|------|--------|
| `lib/klass_hero_web/live/provider/sessions_live.ex` | PubSub fixes, form handlers, modal assigns, program loading |
| `lib/klass_hero_web/live/provider/sessions_live.html.heex` | Create button, modal markup, form template |
| `lib/klass_hero_web/router.ex` | Add `:new` live action for provider sessions |
| `test/klass_hero_web/live/provider/sessions_live_test.exs` | Tests for form, validation, submission, PubSub |

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| PubSub topic strategy | Generic topics + client-side filter | Matches existing ParticipationLive pattern; follow-up issue for provider-specific routing |
| Form UI | Modal overlay | Established codebase pattern (ChildrenLive) |
| Form data source | Plain map via `to_form/2` | Use case accepts params map, not changeset |
| Pre-fill on program select | Yes | Saves repetitive typing; common case is program's regular schedule |
| Date default | Current `@selected_date` | Most intuitive when viewing a specific day |
| Program filter | All provider programs | No status field exists on Program model |
