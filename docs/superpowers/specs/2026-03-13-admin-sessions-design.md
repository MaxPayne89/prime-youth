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

### Admin Layout Assigns

The `admin.html.heex` layout requires `@fluid?`, `@live_resource`, and `@current_url` (normally set by Backpex internals). The custom LiveView must provide these in `mount/3`:

- `fluid?: false` — standard width, not full-bleed
- `live_resource: nil` — no Backpex resource backing this page
- `current_url` — set via an `on_mount` hook that reads `handle_params` URI, or assigned directly in `handle_params/3` from the URI

If `Backpex.HTML.Layout.sidebar_item` or `app_shell` doesn't tolerate `live_resource: nil`, wrap the check or provide a minimal placeholder struct. This will be validated during implementation.

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
- Cursor-based pagination using `Shared.Domain.Types.Pagination` (consistent with other contexts)

Sessions list uses LiveView streams. Clicking a row navigates to detail view.

### Data Enrichment for Index

`ProgramSession` only contains `program_id` — no program name or provider info. The index also needs per-session check-in counts. Strategy:

- Extend `SessionRepository` list queries to join `programs` and `provider_profiles` tables, returning enriched maps with `program_name`, `provider_name` alongside session fields
- Include a subquery/aggregate for participation record counts: `checked_in_count` (status in `[:checked_in, :checked_out]`) and `total_count`
- The `ListSessions` use case returns these enriched maps (not bare `ProgramSession` structs) for the admin context
- This is a single query with joins + aggregates, avoiding N+1 lookups

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

- **Editable fields:** status (dropdown), check-in time, check-out time
- **Required field:** reason for correction (text area)
- **Buttons:** Cancel, Save Correction (disabled until reason is filled and at least one field changed)
- Only one correction row open at a time

## Domain Layer Changes

### New Domain Method: `ParticipationRecord.admin_correct/2`

The existing state machine only allows forward transitions (`registered → checked_in → checked_out`, `registered → absent`). Admin corrections need more flexibility — e.g. correcting `absent → checked_in` when a provider forgot to check in, or `checked_out → checked_in` if check-out was premature.

New method `admin_correct(record, attrs)` on `ParticipationRecord`:
- Accepts any status transition between valid statuses (`:registered`, `:checked_in`, `:checked_out`, `:absent`)
- Updates `check_in_at`, `check_out_at` if provided
- Does NOT use the regular `check_in/3` or `check_out/3` methods (those enforce the forward-only state machine)
- Validates logical consistency: can't set `check_out_at` without `check_in_at` being present

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
- Delegates to `ParticipationRecord.admin_correct/2` for transition validation
- Appends reason to the appropriate notes field with `[Admin correction]` prefix:
  - If `check_in_at` changed → append to `check_in_notes`
  - If `check_out_at` changed → append to `check_out_notes`
  - If only `status` changed → append to `check_in_notes`
  - Append (not replace) to preserve any original provider notes
- Uses optimistic locking (`lock_version`) already on schema
- Updates via existing `ForManagingParticipation` port (no new port methods)

### Extended Use Case: `ListSessions`

Current `list_sessions/1` supports filtering by `program_id` or `date`. Extend to also support:
- `provider_id` filter
- `status` filter
- Date range (not just single date)
- Enriched return type with program name, provider name, and attendance counts (for admin usage)

This requires extending the `ForManagingSessions` port's query method and the `SessionRepository` adapter.

## No Migrations

All database tables already exist: `program_sessions`, `participation_records`, `behavioral_notes`. Correction reasons reuse existing `check_in_notes` / `check_out_notes` fields with `[Admin correction]` prefix (appended, not replaced).

## Files Affected

### New Files
- `lib/klass_hero/participation/application/use_cases/correct_attendance.ex`
- `lib/klass_hero_web/live/admin/sessions_live.ex`
- `lib/klass_hero_web/live/admin/sessions_live.html.heex`
- `test/klass_hero/participation/application/use_cases/correct_attendance_test.exs`
- `test/klass_hero_web/live/admin/sessions_live_test.exs`

### Modified Files
- `lib/klass_hero/participation.ex` — expose `correct_attendance/1`, extend `list_sessions/1` opts
- `lib/klass_hero/participation/domain/models/participation_record.ex` — add `admin_correct/2`
- `lib/klass_hero/participation/application/use_cases/list_sessions.ex` — add provider_id, status, date range filters, enriched return
- `lib/klass_hero/participation/domain/ports/for_managing_sessions.ex` — extend query type for new filters
- `lib/klass_hero/participation/adapters/driven/persistence/repositories/session_repository.ex` — implement new filters + joins
- `lib/klass_hero_web/components/layouts/admin.html.heex` — add sidebar item
- `lib/klass_hero_web/router.ex` — add `/admin/sessions` routes and live_session

## Testing

- **Unit:** `ParticipationRecord.admin_correct/2` — all valid transitions, logical consistency checks
- **Unit:** `CorrectAttendance` use case — valid corrections, missing reason, no changes, note appending, optimistic lock conflicts
- **Unit:** Extended `ListSessions` — filtering by provider, status, date range, enriched return data
- **LiveView:** Sessions index — today mode rendering, filter mode toggle, filter application, pagination
- **LiveView:** Session detail — roster display, correction flow, form validation, save/cancel

## Internationalization

All user-facing labels through gettext (en/de). Follows existing pattern in `priv/gettext/`.
