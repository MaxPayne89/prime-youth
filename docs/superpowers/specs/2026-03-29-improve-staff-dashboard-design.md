# Improve Staff Dashboard — Design Spec

**Issue:** #529 — Staff dashboard shows assigned programs but lacks provider functionality
**Date:** 2026-03-29
**Approach:** Dedicated Staff LiveViews (Approach A)

## Summary

Staff members currently land on `/staff/dashboard` and see their assigned programs as static cards. This spec adds operational functionality: clickable programs, session management, and participation tracking (check-in/check-out). Staff get dedicated LiveViews scoped to their assigned programs — no session creation, no program editing, no broadcasts.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Functionality level | Operational (read + check-in/out) | Staff run sessions day-of; creation/config is provider-owner work |
| Navigation pattern | Route-based (`/staff/sessions`, `/staff/participation/:id`) | Matches provider pattern, bookmarkable, keeps LiveViews focused |
| Session scoping | Assigned programs only (via `staff_member.tags`) | Least-privilege; empty tags = all programs (general staff) |
| LiveView strategy | Dedicated staff LiveViews, no reuse of provider views | Clean auth boundaries, simpler templates, no role conditionals |
| Roster display | Simple staff-specific modal (not reusing `roster_modal`) | KISS — enrolled list only, no import/invite/messaging features |

## Routes

All routes live under the existing `:require_staff_provider` live_session:

```elixir
live_session :require_staff_provider,
  layout: {KlassHeroWeb.Layouts, :app},
  on_mount: [
    {KlassHeroWeb.UserAuth, :require_authenticated},
    {KlassHeroWeb.UserAuth, :require_staff_provider},
    {KlassHeroWeb.Hooks.RestoreLocale, :restore_locale}
  ] do
  scope "/staff", Staff do
    live "/dashboard", StaffDashboardLive, :index          # existing
    live "/sessions", StaffSessionsLive, :index            # new
    live "/participation/:session_id", StaffParticipationLive, :show  # new
  end
end
```

## Navigation Flow

```
Staff Dashboard (/staff/dashboard)
  ├── Program Card → [Sessions] → /staff/sessions?program_id=<id>
  │                                   └── Session → [Manage] → /staff/participation/<session_id>
  └── Program Card → [Roster]   → inline modal (enrolled children list)
```

## Component 1: StaffDashboardLive (Enhanced)

**File:** `lib/klass_hero_web/live/staff/staff_dashboard_live.ex` (modify existing)

### Changes

- Program cards become actionable with two buttons:
  - **Sessions** — `<.link navigate={~p"/staff/sessions?program_id=#{program.id}"}>`
  - **Roster** — `phx-click="view_roster"` opening a simple modal

- New event handlers:
  - `"view_roster"` — loads enrolled children via `Enrollment.list_program_enrollments/1`, verifies program is in assigned set
  - `"close_roster"` — resets roster assigns

- New assigns: `show_roster`, `roster_entries`, `roster_program_name`, `roster_program_id`

### Staff Roster Modal

A simple, staff-specific roster component (~30-40 lines HEEx). Shows:
- Program name as title
- List of enrolled children (name, enrollment date)
- Close button

No CSV import, no invite management, no messaging — just the enrolled list.

## Component 2: StaffSessionsLive (New)

**File:** `lib/klass_hero_web/live/staff/staff_sessions_live.ex`

### Mount

1. Read `scope.staff_member` — extract `provider_id` and `tags`
2. Load assigned programs (filter by tags; empty tags = all programs)
3. Build `MapSet` of assigned program IDs for authorization
4. If `program_id` query param present and valid, filter to that program
5. Load sessions for today via `Participation.list_provider_sessions/2`
6. Post-filter sessions to only those whose `program_id` is in the assigned set
7. Subscribe to PubSub topic `participation:provider:#{provider_id}`

### Features

- **Date picker** — navigate between days, reload sessions
- **Session list** — program name, time range, status badge, checked-in count
- **Start Session** button — calls `Participation.start_session/1` after verifying program ownership
- **Complete Session** button — calls `Participation.complete_session/1` after verifying program ownership
- **Manage** link — navigates to `/staff/participation/:session_id`
- **Real-time updates** — PubSub handlers for session lifecycle events (filtered to assigned programs)

### Omitted (Provider-Owner Only)

- Create session form (no `:new` action)
- Program selection dropdown (sessions pre-filtered)

## Component 3: StaffParticipationLive (New)

**File:** `lib/klass_hero_web/live/staff/staff_participation_live.ex`

### Mount

1. Receive `session_id` from URL params
2. Load session with enriched roster via `Participation.get_session_with_roster_enriched/1`
3. **Authorization gate:** verify session's `program_id` is in staff member's assigned program set. Redirect to `/staff/sessions` with error flash if unauthorized.
4. Subscribe to PubSub topics for real-time updates

### Features

- **Roster list** — child name, attendance status indicator
- **Check In** — calls `Participation.record_check_in/1` with `checked_in_by: scope.user.id`
- **Check Out** — expandable form with optional notes, calls `Participation.record_check_out/1`
- **Mark Absent** — calls `Participation.mark_absent/1`
- **Behavioral notes** — submit notes for individual children
- **Real-time updates** — PubSub for check-in/check-out events from other users

### Omitted (Provider-Owner Only)

- Revision forms (correcting historical records)
- Direct parent messaging (entitlement gated to provider tier)

## Authorization Model

Three layers:

### Layer 1: Router (Existing)

`:require_staff_provider` mount hook ensures only users with an active `staff_member` record access `/staff/*` routes.

### Layer 2: Program Scoping

Every staff LiveView filters data to assigned programs:

```elixir
defp assigned_programs(staff_member) do
  all = ProgramCatalog.list_programs_for_provider(staff_member.provider_id)
  if staff_member.tags == [], do: all, else: Enum.filter(all, &(&1.category in staff_member.tags))
end
```

This function is duplicated in each LiveView (3 call sites). If it grows more complex, extract to a helper — but not preemptively.

### Layer 3: Event Verification

Before executing any mutation (`start_session`, `complete_session`, `check_in`, `check_out`), verify the target session's `program_id` is in the staff member's assigned program ID `MapSet`:

```elixir
if MapSet.member?(socket.assigns.assigned_program_ids, session.program_id) do
  # proceed
else
  {:noreply, put_flash(socket, :error, gettext("Unauthorized"))}
end
```

### IDOR Protection

- Staff cannot access sessions for programs outside their tag assignments
- Staff cannot access sessions for other providers (provider_id mismatch caught by data scoping)
- Roster view verifies program ownership before loading enrollment data

## Database Changes

None. Existing tables and relationships are sufficient:
- `staff_members` has `provider_id` and `tags`
- `sessions` has `program_id`
- `programs` has `provider_id` and `category`
- `participation_records` linked to sessions

## Testing Strategy

### Unit Tests

- `StaffSessionsLive` — mount loads only assigned program sessions, date navigation, start/complete session authorization
- `StaffParticipationLive` — mount with valid/invalid session, check-in/check-out, authorization rejection for non-assigned programs
- `StaffDashboardLive` — enhanced cards render action buttons, roster modal open/close, roster authorization

### Authorization Tests

- Staff with tags `["sports"]` cannot view roster for an `"arts"` program
- Staff with tags `["sports"]` cannot start a session for an `"arts"` program
- Staff with empty tags can access all provider programs
- Staff from provider A cannot access provider B's sessions (data scoping)

## Files Changed

| File | Action | Description |
|---|---|---|
| `lib/klass_hero_web/live/staff/staff_dashboard_live.ex` | Modify | Add action buttons, roster modal, event handlers |
| `lib/klass_hero_web/live/staff/staff_sessions_live.ex` | Create | Date-based session list with start/complete |
| `lib/klass_hero_web/live/staff/staff_participation_live.ex` | Create | Check-in/check-out participation management |
| `lib/klass_hero_web/router.ex` | Modify | Add two new routes under `:require_staff_provider` |
| `test/klass_hero_web/live/staff/staff_sessions_live_test.exs` | Create | Session list and operation tests |
| `test/klass_hero_web/live/staff/staff_participation_live_test.exs` | Create | Participation operation tests |
| `test/klass_hero_web/live/staff/staff_dashboard_live_test.exs` | Modify | Tests for new action buttons and roster |
