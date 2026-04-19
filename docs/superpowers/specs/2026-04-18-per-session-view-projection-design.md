# Per-Session View Projection

**Issue:** #373 — [FEATURE] Add per-session view to program inventory dashboard
**Date:** 2026-04-18
**Status:** Approved

## Problem

Providers managing a program on the provider dashboard can see program-level data (title, status, enrollment count, staff) but cannot drill into individual sessions. To see sessions, they currently have no UI at all. The admin area has a sessions view backed by a live 4-table JOIN in `SessionRepository.list_admin_sessions/1`, but that is not surfaced to providers, and its shape is admin-centric.

The AC requires:

- A "Sessions" button in the Actions column of the provider dashboard's program inventory.
- A modal where each row represents a session with columns: date/time, assigned provider, cover provider, attendance.
- Sessions sorted by earliest date.
- Completed sessions visually distinct from upcoming ones.

## Solution

Introduce a new event-driven projection — `ProviderSessionDetails` — in the **Provider** context. The projection denormalizes session lifecycle data (from Participation), attendance counts (from Participation), and staff assignment (from Provider) into a single `provider_session_details` read table, queried through a new `ForQueryingSessionDetails` port.

The provider dashboard's new Sessions modal reads only from this projection via a thin use case — no cross-context orchestration in the LiveView, and no new ACL adapter is introduced.

**Scope boundary:** this projection powers the new provider modal only. The existing admin JOIN query (`list_admin_sessions/1`) is left untouched; a follow-up ticket can migrate admin to the same projection and retire the JOIN.

**Cover provider:** schema-reserved but deferred. The current domain (`ProgramStaffAssignment`) models staff at program level with no primary/cover distinction. Cover columns are nullable and populated only when the domain is extended.

## Architecture Overview

```
Participation Context                   Provider Context
      |                                       |
  session_created                    staff_assigned_to_program
  session_started                    staff_unassigned_from_program
  session_completed
  session_cancelled (add if missing)
  roster_seeded
  child_checked_in
  child_checked_out
  child_marked_absent
      |                                       |
      +--------------- PubSub -----------------+
                           |
        Provider: ProviderSessionDetails Projection (GenServer)
            - maintains provider_session_details table
            - self-heals on boot via handle_continue(:bootstrap)
            - exposes rebuild/0 escape hatch
                           |
                provider_session_details
                           |
        Provider: SessionDetailsRepository (implements port)
                           |
        Provider: ListProgramSessions (use case / query)
                           |
        Web: DashboardLive "view_sessions" handler
                           |
        Web: sessions_modal component (uses participation_status)
```

Cross-context isolation is preserved:

- The projection consumes only integration events, not other contexts' Ecto schemas at runtime.
- The projection's bootstrap query reaches across context tables — same pattern as the existing `list_admin_sessions/1` — and is the one acknowledged exception. If `boundary-checker` flags it later, introduce per-context read helpers (`Participation.list_all_sessions_for_bootstrap/0`, etc.) and call those.
- LiveView reads through a single Provider-context port — no multi-context orchestration in the web layer.

## Events Consumed

### Participation events

| Topic | Handler effect |
|---|---|
| `integration:participation:session_created` | Insert row; `status=:scheduled`, `total_count=0`, `checked_in_count=0`; resolve current program assignment and populate `current_assigned_staff_*` |
| `integration:participation:session_started` | Update `status=:in_progress` for `session_id` |
| `integration:participation:session_completed` | Update `status=:completed` for `session_id` |
| `integration:participation:session_cancelled` | Update `status=:cancelled` for `session_id` |
| `integration:participation:roster_seeded` | Set `total_count = seeded_count` for `session_id` |
| `integration:participation:child_checked_in` | Atomic `checked_in_count += 1` for `session_id` |
| `integration:participation:child_checked_out` | No-op on counts (child already counted on check-in) |
| `integration:participation:child_marked_absent` | No-op on counts |

**`session_cancelled`** — verify the event currently exists in Participation's integration events. If absent, add it (domain + integration promotion) when `ProgramSession.status` transitions to `:cancelled`. Payload: `session_id`, `program_id`.

### Provider events

| Topic | Handler effect |
|---|---|
| `integration:provider:staff_assigned_to_program` | Bulk `UPDATE` all rows where `program_id = event.program_id AND status = :scheduled`; set `current_assigned_staff_*` from event |
| `integration:provider:staff_unassigned_from_program` | Bulk `UPDATE` all rows where `program_id = event.program_id AND status = :scheduled`; clear `current_assigned_staff_*` |

**"Scheduled-only" rule** — staff reassignment affects only sessions not yet delivered (`status = :scheduled`). Sessions that are in progress, completed, or cancelled keep whatever staff was displayed at the time. This is semantically stricter than a date-based filter and correctly handles same-day edge cases (a session completed earlier today, or one currently running).

### Handler idempotency & ordering

- `session_created` uses upsert (`ON CONFLICT` with `replace_all_except`) — duplicate delivery is a no-op.
- All other handlers use `UPDATE WHERE session_id = ?` — running twice is a no-op.
- Counter handlers use atomic SQL increments — safe under concurrent delivery.
- Events arriving for unknown `session_id` (e.g., `child_checked_in` before `session_created`) affect zero rows. A warning is logged. The next boot's bootstrap reconciles counts from the write table.

### Counter strategy

Attendance counts are stored as integers and mutated via atomic SQL increments. Check-outs and absences do not decrement — once a child is counted on check-in, they stay counted. The only scenario that would require a decrement is undoing a check-in, which is not a modeled write operation today. If added later, a corresponding `child_check_in_reversed` event would handle it.

Reconciliation is guaranteed by self-healing bootstrap: every boot recomputes counts from `participation_records`, so any drift is erased on the next deploy.

## Data Model

### Migration

```elixir
defmodule KlassHero.Repo.Migrations.CreateProviderSessionDetails do
  use Ecto.Migration

  def change do
    create table(:provider_session_details, primary_key: false) do
      add :session_id,                  :binary_id, primary_key: true
      add :program_id,                  :binary_id, null: false
      add :program_title,               :string,    null: false
      add :provider_id,                 :binary_id, null: false

      add :session_date,                :date,      null: false
      add :start_time,                  :time,      null: false
      add :end_time,                    :time,      null: false
      add :status,                      :string,    null: false

      add :current_assigned_staff_id,   :binary_id
      add :current_assigned_staff_name, :string
      add :cover_staff_id,              :binary_id
      add :cover_staff_name,            :string

      add :checked_in_count,            :integer,   null: false, default: 0
      add :total_count,                 :integer,   null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:provider_session_details, [:provider_id, :program_id, :session_date])
    create index(:provider_session_details, [:provider_id, :session_date])
  end
end
```

No foreign keys. Projections are intentionally decoupled from source tables to avoid coupling deployment order and to prevent source-table deletes from cascading into the read model.

### Read Model DTO

```elixir
defmodule KlassHero.Provider.Domain.ReadModels.SessionDetail do
  defstruct [
    :session_id, :program_id, :program_title, :provider_id,
    :session_date, :start_time, :end_time, :status,
    :current_assigned_staff_id, :current_assigned_staff_name,
    :cover_staff_id, :cover_staff_name,
    :checked_in_count, :total_count
  ]
end
```

### Ecto Schema

`ProviderSessionDetailSchema` — binary_id primary key on `session_id`; `status` as `Ecto.Enum` with values `[:scheduled, :in_progress, :completed, :cancelled]`.

## Port Contract

```elixir
defmodule KlassHero.Provider.Domain.Ports.ForQueryingSessionDetails do
  alias KlassHero.Provider.Domain.ReadModels.SessionDetail

  @callback list_by_program(provider_id :: binary(), program_id :: binary()) ::
              [SessionDetail.t()]
end
```

Sorted by `session_date` ascending, then `start_time` ascending. No pagination — session volume per program is bounded (typically < 50).

## Module Layout

```
lib/klass_hero/provider/
  domain/
    read_models/session_detail.ex
    ports/for_querying_session_details.ex
  adapters/driven/
    persistence/
      schemas/provider_session_detail_schema.ex
      mappers/provider_session_detail_mapper.ex
      repositories/session_details_repository.ex
    projections/provider_session_details.ex
  application/queries/list_program_sessions.ex
```

## Dependency Injection

```elixir
# config/config.exs (under existing :provider key)
config :klass_hero, :provider,
  # ... existing bindings ...,
  for_querying_session_details:
    KlassHero.Provider.Adapters.Driven.Persistence.Repositories.SessionDetailsRepository
```

## Supervision & Bootstrap

### Startup

Matches the `ProgramListings` pattern:

```elixir
def init(_opts) do
  Enum.each(@topics, &Phoenix.PubSub.subscribe(KlassHero.PubSub, &1))
  {:ok, %{bootstrapped: false}, {:continue, :bootstrap}}
end

def handle_continue(:bootstrap, state), do: attempt_bootstrap(state)
```

Subscribing before bootstrapping ensures no events are missed during startup.

### Bootstrap query

A single query joins `program_sessions`, `programs`, `program_staff_assignments`, `staff_members`, and `participation_records` to compute every row of `provider_session_details` in one pass. Results are batch-upserted with `on_conflict: {:replace_all_except, [:session_id, :inserted_at]}` — safe to run alongside in-flight event handlers.

### `rebuild/0` escape hatch

```elixir
def rebuild(name \\ __MODULE__), do: GenServer.call(name, :rebuild, :infinity)
```

Re-runs the bootstrap query. Used after seeds (which bypass event publishing) or any time drift is suspected.

### Supervision

Add `ProviderSessionDetails` to the Provider context supervision tree with a **permanent** restart policy (same as `ProgramListings`), so repeated failures escalate rather than silently retry.

### Retry

`handle_info(:retry_bootstrap, state) -> {:noreply, state, {:continue, :bootstrap}}` — reuses the same continue path when transient failures occur during boot.

### Deletion of sessions

Not a modeled write operation today. If added later, a `session_deleted` event handler (plus a `DELETE ... WHERE session_id NOT IN (...)` pass in `rebuild/0`) would handle it.

## Web Layer

### Use case

```elixir
defmodule KlassHero.Provider.Application.Queries.ListProgramSessions do
  @for_querying_session_details Application.compile_env!(
    :klass_hero, [:provider, :for_querying_session_details]
  )

  def run(provider_id, program_id),
    do: @for_querying_session_details.list_by_program(provider_id, program_id)
end
```

Authorization (does this provider own this program?) is handled by the LiveView's auth pipeline upstream — the query assumes a trusted `(provider_id, program_id)` pair.

### LiveView additions (`DashboardLive`)

- Socket assign: `:sessions_modal` — `nil` when closed, `%{program_id, program_title, sessions}` when open.
- `handle_event("view_sessions", %{"program-id" => id, "program-title" => title}, socket)` — calls `ListProgramSessions.run/2` and assigns modal state.
- `handle_event("close_sessions", _, socket)` — clears modal state.

### "Sessions" button

Added to the Actions column of `programs_table` in `provider_components.ex:1366–1385`. Icon: `hero-calendar-days`. `aria-label` gettext'd.

### `sessions_modal/1` component

Mirrors `roster_modal/1` (line 1456) structure — overlay, `phx-click-away` close, titled header, close (X) button — but renders a single table (no tabs).

Columns:

1. **Date / time** — `session.session_date` + `start_time`–`end_time`, formatted.
2. **Assigned staff** — `current_assigned_staff_name` or `gettext("Unassigned")`.
3. **Cover** — `cover_staff_name` or `"—"`. Reserved column, always dash for now.
4. **Attendance** — `{checked_in_count} / {total_count}`. Hidden when `status == :cancelled` (matches admin sessions view precedent at `admin/sessions_live.html.heex:116`).
5. **Status** — `<.participation_status status={session.status} size="sm" />`.

Sort is produced by the repository — no client-side sort logic.

**Empty state:** icon + "No sessions scheduled yet." when `sessions == []`.

### Component extension: `participation_status`

Add a `:cancelled` clause to the existing component at `participation_components.ex:126`:

- Color: `bg-red-100 text-red-700 border border-red-300`
- Icon: `hero-x-circle`
- Label: `gettext("Cancelled")`

The same badge is used by anywhere else that renders session status (for semantic consistency).

### Internationalization

All user-facing strings through `gettext/1`. German translations added to `priv/gettext/de/LC_MESSAGES/default.po`.

### Accessibility

- Sessions button `aria-label` set.
- Modal carries `role="dialog"`, `aria-labelledby={modal_title_id}`, `aria-modal="true"`.
- `phx-click-away` closes (matches `roster_modal`).

## Testing Strategy

### Unit tests — projection event handlers

`test/klass_hero/provider/adapters/driven/projections/provider_session_details_test.exs`

- Each event type asserts its resulting DB state.
- Idempotency: repeat delivery is a no-op.
- Ordering: `child_checked_in` before `session_created` logs a warning; bootstrap reconciles.
- Staff reassignment: past session unchanged, future session updated.
- Status transitions: `scheduled → in_progress → completed`; `:cancelled` as terminal.

### Unit tests — repository

`test/klass_hero/provider/adapters/driven/persistence/repositories/session_details_repository_test.exs`

- `list_by_program/2` returns sorted rows.
- Unknown program returns `[]`.
- No cross-provider leakage.
- Full DTO shape populated.

### Bootstrap test

- Seed write tables directly, start projection, assert full population.
- Drift the read table manually, call `rebuild/0`, assert reconciliation.

### Use-case test

- Stubs the port, asserts delegation.

### LiveView test

`test/klass_hero_web/live/provider_live/dashboard_live_test.exs`

- Click Sessions button opens modal.
- Columns render expected values for a known session.
- `:completed` / `:scheduled` / `:cancelled` render distinct badges.
- Attendance count hidden for cancelled rows.
- Empty state for zero-session program.
- Close (X) and click-away both close the modal.

### Component render tests

- `sessions_modal/1` structural render.
- `participation_status/1` with `:cancelled`.

### Architecture validation

Run `/review-architecture` post-implementation. Expected-clean on: projection context placement, port naming, DI wiring, use-case shape. Expected flag on bootstrap's cross-context table reads — resolvable via per-context read helpers or explicit Boundary config.

### Non-goals

- No load testing (volumes don't warrant).
- No new Ecto tests (upsert is standard).
- No duplicate tests for the unchanged parts of `participation_status`.

## Rollout

1. Merge schema + projection + port + repository + wiring + tests. Projection boots, self-populates from existing write data on first deploy.
2. Merge use case + LiveView modal + button + component extension. Feature visible to providers.
3. Follow-up ticket: migrate `list_admin_sessions/1` to read from the same projection; retire the JOIN.
4. Follow-up ticket (issue #373 sub-issue): cover provider — domain change to support per-session delivery, new event, projection extension.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Projection drift from write model | Self-healing bootstrap on every boot + `rebuild/0` |
| `session_cancelled` event missing | Verify before implementation; add if absent |
| Bootstrap query crosses context boundaries | Acknowledge; refactor to per-context helpers if boundary-checker flags |
| Past-session staff display flips on reassignment | `status = :scheduled` filter in bulk update |
| Counter races under concurrent event delivery | Atomic SQL increments |
| Undo of check-in not reflected | Not a modeled operation today; out of scope |

## Open Items Before Implementation

1. Confirm whether `session_cancelled` integration event exists in Participation; add if missing.
2. Confirm `ProviderSessionDetails` supervision lands on the Provider context supervisor (vs. the application-level supervisor). The house style (`ProgramListings` location) dictates the answer.
