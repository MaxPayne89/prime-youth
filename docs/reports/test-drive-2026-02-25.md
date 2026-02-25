# Test Drive Report - 2026-02-25

## Scope
- **Mode**: branch (`git diff main...HEAD`)
- **Files changed**: 28 (~4,000 lines)
- **Routes affected**: `/provider/dashboard/programs` (roster modal, CSV import)
- **Key features tested**: CSV import, roster modal with tabs, invite list/resend/delete, event-driven email pipeline

## Backend Checks (Tidewave MCP)

### Passed

- **Schema integrity**: `BulkEnrollmentInviteSchema` has 27 fields matching all 27 DB columns in `bulk_enrollment_invites` table
- **list_program_invites("nonexistent-uuid")**: Returns `{:ok, []}` as expected
- **count_program_invites("nonexistent-uuid")**: Returns `0` as expected
- **delete_invite("nonexistent", "nonexistent")**: Returns `{:error, :not_found}` as expected
- **resend_invite("nonexistent", "nonexistent")**: Returns `{:error, :not_found}` as expected
- **CSV import (valid data)**: `import_enrollment_csv/2` with M/D/YYYY dates returns `{:ok, %{created: 2}}`
- **CSV import (ISO dates)**: Correctly rejects `YYYY-MM-DD` format with descriptive parse errors
- **list_program_invites (real data)**: Returns invites ordered alphabetically by child last name
- **resend_invite (real data)**: Resets status to "pending", clears invite_token and invite_sent_at
- **Email pipeline end-to-end**: After import, invites receive tokens and emails are sent to dev mailbox
- **Invite email content**: Correct child name, program name, and claim link in email body
- **No errors in application logs**: Only expected cross-live-session redirect warning

### Issues Found

- **[info]**: Invite email claim links use `http://localhost/invites/...` (no port 4000)
  - Location: Email template / URL config
  - Expected: `http://localhost:4000/invites/...` in dev
  - Actual: `http://localhost/invites/...`
  - Impact: Links are not clickable in dev without manually adding `:4000`. Likely a `url: [host: "localhost"]` config in `config/dev.exs` missing the port for the email URL helper. Not a production issue (production uses real domain).

## UI Checks (Playwright MCP)

### Pages Tested

- **/provider/dashboard/programs**: PASS
  - Program inventory table renders correctly with 2 programs
  - Each program row has Preview, View Roster, and Edit action buttons
  - Screenshot: `screenshots/programs-tab.png`

- **Roster Modal - Enrolled tab**: PASS
  - Opens with correct title "Roster: Youth Fitness Basics"
  - Tabs show correct counts: "Enrolled (0)", "Invites (2)"
  - Default tab is "Enrolled" with empty state "No enrollments yet."
  - Screenshot: `screenshots/roster-modal-enrolled-tab.png`

- **Roster Modal - Invites tab**: PASS
  - Displays invite table with columns: Child Name, Guardian Email, Status, Actions
  - Invites ordered by last name (Mueller before Schmidt)
  - Status badges render correctly (Sent = green, Pending = orange)
  - Resend and Remove action buttons visible per row
  - Screenshot: `screenshots/roster-modal-invites-tab.png`

- **CSV Upload - Valid file**: PASS
  - "Upload CSV" button opens native file chooser
  - Selected file name displayed with Import/Cancel buttons
  - Import succeeds with flash "Imported 1 families."
  - New invite appears in table immediately
  - Tab count updates from "Invites (1)" to "Invites (2)"
  - Screenshot: `screenshots/csv-import-success.png`

- **CSV Upload - Invalid file**: PASS
  - Import shows inline error panel with "Import failed" heading (red)
  - Error details are specific: "Row 2: invalid date format in column child_date_of_birth: bad-date (row 2)"
  - Existing invites remain unaffected (all-or-nothing semantics)
  - Screenshot: `screenshots/csv-import-error.png`

- **Resend Invite**: PASS
  - Click Resend on "Ben Mueller" (status: Sent) -> flash "Invite resent successfully."
  - Status changes from "Sent" to "Pending"

- **Delete Invite**: PASS
  - Click Remove on "Anna Schmidt" -> flash "Invite removed."
  - Row disappears, tab count updates from "Invites (2)" to "Invites (1)"

- **Download Template**: PASS
  - Link points to `/downloads/enrollment-import-template.csv`
  - Template has 18 headers matching expected CSV format

### Issues Found

- **[warning]**: Mobile responsive layout truncation
  - Steps to reproduce: Resize viewport to 375x667, open roster modal, switch to Invites tab
  - Expected: All columns visible or horizontally scrollable
  - Actual: Status and Actions columns are truncated/hidden. Status badges show as "Pe..." and action buttons (Resend/Remove) are not accessible.
  - Screenshot: `screenshots/roster-modal-mobile.png`
  - Impact: Mobile users cannot see invite status or perform resend/delete actions from the roster modal

- **[info]**: SVG path console errors on homepage
  - 2 console errors: `<path> attribute d: Expected moveto...` for icon images
  - Pre-existing issue, not introduced by this branch

## Auto-Fixes Applied

None. No trivial issues (typos, missing IDs, broken CSS) were found requiring auto-fix.

## Recommendations

1. **Mobile roster modal** (medium priority): Add `overflow-x: auto` to the invite table container or switch to a card-based layout on mobile to make Status and Actions accessible on narrow screens.

2. **Email URL config** (low priority): Check `config/dev.exs` URL configuration for the endpoint used in invite email generation. The claim link URL should include `:4000` in dev mode. Not urgent since production will use the real domain.

3. **CSV date format documentation** (low priority): The CSV template file has no format hints for the date column. Consider adding a comment row or tooltip indicating `M/D/YYYY` format to reduce import errors for providers.
