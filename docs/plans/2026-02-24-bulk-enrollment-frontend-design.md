# Design: Bulk Enrollment Frontend + Supporting Backend (#176)

> **Context:** Enrollment | **Issue:** #176
> **Date:** 2026-02-24

## Purpose

Wire up the provider-facing UI for bulk enrollment: CSV upload, invite management table with resend/remove actions, and the backend functions needed to support them. The core import → email → claim → enroll pipeline is done; this covers the provider dashboard experience.

## Roster Modal Redesign

Extend the existing `roster_modal` with tabs:

- **Enrolled (N)** — existing roster content, unchanged
- **Invites (N)** — new tab with upload + invite table

Tab labels include counts. Default tab is "Enrolled" (existing behavior preserved).

### Invites Tab Layout

```
[Upload CSV]  [Download Template]
─────────────────────────────────────
Child Name    │ Guardian Email │ Status │ Actions
Jane Smith    │ p@test.com     │ Sent   │ ↻  🗑
Tom Smith     │ p@test.com     │ Failed │ ↻  🗑
Ali Johnson   │ a@test.com     │ Enrolled│

(empty state: "No invites yet. Upload a CSV to invite families.")
```

- **Resend** shown for: `pending`, `invite_sent`, `failed`
- **Remove** shown for: `pending`, `invite_sent`, `failed` (not `enrolled`/`registered`)
- No actions for terminal/progressed statuses

## CSV Upload Flow

LiveView `allow_upload`:
- Accept: `.csv` only
- Max size: 2MB
- Single file

Flow:
1. Click "Upload CSV" → file picker
2. File selected → "Import" button confirms
3. Success → flash "Imported N families" + refresh invite list
4. Error → structured error display inline below upload area

"Add More" = click "Upload CSV" again.

### Error Display

```
Import failed — 3 errors found

Row 2: "guardian_email" is not a valid email
Row 5: Program "Summer Camp" not found in your catalog
Row 5: "child_date_of_birth" must be in the past
```

## Static CSV Template

`priv/static/downloads/enrollment-import-template.csv` — header row matching expected columns. Download link with note: "Open with Excel, Google Sheets, or any spreadsheet app."

## Backend Additions

### New Repository Callbacks (ForStoringBulkEnrollmentInvites)

| Function | Purpose |
|---|---|
| `list_by_program(program_id)` | All invites for a program, ordered by `child_last_name` |
| `count_by_program(program_id)` | Total count for tab label |
| `delete(id)` | Hard delete a single invite |

### New Use Cases

| Use Case | Purpose |
|---|---|
| `ListProgramInvites` | Fetch invites for a program |
| `ResendInvite` | Reset to `pending`, clear token + `invite_sent_at`, dispatch `bulk_invites_imported` for re-processing |
| `DeleteInvite` | Hard delete an invite record |

### New Facade Functions (KlassHero.Enrollment)

| Function | Delegates To |
|---|---|
| `list_program_invites(program_id)` | `ListProgramInvites` |
| `count_program_invites(program_id)` | Repository |
| `resend_invite(invite_id)` | `ResendInvite` |
| `delete_invite(invite_id)` | `DeleteInvite` |

### Resend Use Case Detail

1. Fetch invite by ID
2. Validate status is resendable (`pending`, `invite_sent`, `failed`)
3. Transition to `pending` + clear `invite_token` + clear `invite_sent_at`
4. Dispatch `bulk_invites_imported` event for the invite's program — existing pipeline picks it up

### Status Badge Mapping

| DB Status | Display | Color |
|---|---|---|
| `pending` | Pending | Yellow |
| `invite_sent` | Sent | Blue |
| `registered` | Registered | Purple |
| `enrolled` | Enrolled | Green |
| `failed` | Failed | Red |

## Decisions

- **Upload in roster modal, not program form** — keeps invite workflow cohesive; program form already large
- **Hard delete for remove** — invites are staging records, not auditable entities
- **Resend via reset-to-pending** — reuses existing email pipeline; dedicated use case orchestrates
- **LiveView upload, not JSON controller** — call use case directly, no HTTP round-trip to self
- **CSV template only** — matches accepted format, opens in Excel/Sheets
- **Tab counts, no status breakdown** — per-row status is sufficient
