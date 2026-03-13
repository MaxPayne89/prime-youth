# Admin Sessions Dashboard — Design Spec

**Issue:** #344 — [TASK] Add Participation to Admin Dashboard
**Date:** 2026-03-13

## Purpose

Operational admin dashboard for viewing participation sessions and correcting attendance. Designed for daily operations — default view shows today's sessions across all providers, with a filter mode for historical lookup.

## Requirements

- Default "today" view showing all sessions with status and head counts
- Filter mode: provider, program, date range, status
- Session detail with full roster (child name, status, check-in/out times, behavioral note status)
- Behavioral notes: read-only visibility only
- Admin can correct attendance: change status and/or edit check-in/check-out times
- Corrections require a reason (text field, mandatory)
- No mass destructive edits
- No session creation — view and correct only
- Accessible via admin sidebar alongside existing Backpex pages

## Architecture

### Approach: Custom LiveView (not Backpex)

Backpex is CRUD-oriented. This page is an operational dashboard with dual-mode views, nested rosters, and inline corrections — a custom LiveView fits better. Compare to the existing provider `SessionsLive` (similar domain, different audience).

### Routing & Layout

- Route: `/admin/sessions` (index), `/admin/sessions/:id` (show)
- Layout: `{KlassHeroWeb.Layouts, :admin}` — renders inside the Backpex admin shell with sidebar
- New `live_session` under admin scope (cannot share `:backpex_admin` due to `Backpex.InitAssigns` expecting Backpex resources)
- Auth: `require_authenticated` + `require_admin` on_mount hooks (same as existing admin pages)

### Sidebar Integration

Add `<Backpex.HTML.Layout.sidebar_item>` to `admin.html.heex`:
- Label: "Sessions"
- Icon: `hero-calendar-days`
- Route: `/admin/sessions`

## Pages

### Sessions Index (`/admin/sessions`)

Two modes toggled via a tab-like switcher:

**Today mode (default):**
- Shows all sessions for today across all providers
- Each row: program name, provider name, time range, status badge, check-in count (e.g. "8 / 12")
- Sorted by start time

**Filter mode:**
- Filter controls: provider (dropdown), program (dropdown), date range, status (dropdown)
- Same row format but with full date shown (since results span multiple days)
- Paginated results

Sessions list uses LiveView streams. Clicking a row navigates to detail view.

### Session Detail (`/admin/sessions/:id`)

**Header:** program name, provider, date, time range, session status badge, back link to index.

**Roster table columns:**
| Column | Content |
|--------|---------|
| Child | Full name |
| Status | Badge: registered, checked_in, checked_out, absent |
| Check-in | Time or — |
| Check-out | Time or — |
| Notes | Behavioral note status badge (read-only): pending, approved, or — |
| Action | "Correct" link |

### Correction Flow

Clicking "Correct" expands the row inline (no modal, no separate page):

- **Editable fields:** status (dropdown, valid transitions only), check-in time, check-out time
- **Required field:** reason for correction (text area)
- **Buttons:** Cancel, Save Correction (disabled until reason is filled and at least one field changed)
- Only one correction row open at a time
- Status dropdown respects domain state machine (e.g. can't go from checked_out back to registered)

## Domain Layer Changes

### New Use Case: `CorrectAttendance`

Location: `lib/klass_hero/participation/application/use_cases/correct_attendance.ex`

**Input:**
- `record_id` (required)
- `status` (optional — new status)
- `check_in_at` (optional — corrected time)
- `check_out_at` (optional — corrected time)
- `reason` (required — text explaining the correction)

**Behavior:**
- Validates at least one field (status or times) is being changed
- Validates status transitions via `ParticipationRecord` domain model state machine
- Stores reason prefixed with `[Admin correction]` in the appropriate notes field (`check_in_notes` / `check_out_notes`)
- Uses optimistic locking (`lock_version`) already on schema
- Updates via existing `ForManagingParticipation` port (no new port methods)

### Extended Use Case: `ListSessions`

Current `list_sessions/1` supports filtering by `program_id` or `date`. Extend to also support:
- `provider_id` filter
- `status` filter
- Date range (not just single date)

This requires extending the `ForManagingSessions` port's query method and the `SessionRepository` adapter.

## No Migrations

All database tables already exist: `program_sessions`, `participation_records`, `behavioral_notes`. Correction reasons reuse existing `check_in_notes` / `check_out_notes` fields with `[Admin correction]` prefix.

## Files Affected

### New Files
- `lib/klass_hero/participation/application/use_cases/correct_attendance.ex`
- `lib/klass_hero_web/live/admin/sessions_live.ex`
- `lib/klass_hero_web/live/admin/sessions_live.html.heex`
- `test/klass_hero/participation/application/use_cases/correct_attendance_test.exs`
- `test/klass_hero_web/live/admin/sessions_live_test.exs`

### Modified Files
- `lib/klass_hero/participation.ex` — expose `correct_attendance/1`, extend `list_sessions/1` opts
- `lib/klass_hero/participation/application/use_cases/list_sessions.ex` — add provider_id, status, date range filters
- `lib/klass_hero/participation/domain/ports/for_managing_sessions.ex` — extend query type for new filters
- `lib/klass_hero/participation/adapters/driven/persistence/repositories/session_repository.ex` — implement new filters
- `lib/klass_hero_web/components/layouts/admin.html.heex` — add sidebar item
- `lib/klass_hero_web/router.ex` — add `/admin/sessions` routes and live_session

## Testing

- **Unit:** `CorrectAttendance` use case — valid corrections, invalid transitions, missing reason, optimistic lock conflicts
- **Unit:** Extended `ListSessions` — filtering by provider, status, date range
- **LiveView:** Sessions index — today mode rendering, filter mode toggle, filter application
- **LiveView:** Session detail — roster display, correction flow, form validation, save/cancel

## Internationalization

All user-facing labels through gettext (en/de). Follows existing pattern in `priv/gettext/`.
