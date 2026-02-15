# Test Drive Report - 2026-02-15

## Scope
- Mode: branch (main...HEAD)
- Files changed: 31
- Lines: ~2350 added, ~367 removed
- Routes affected: none new; existing `/provider/dashboard/programs`, `/programs/:id`, `/programs`, `/dashboard`

## Backend Checks

### Passed
- **DB Migration**: New columns present (`meeting_days` array, `meeting_start_time` time, `meeting_end_time` time, `start_date` date, `end_date` date). Old `schedule` column removed.
- **ProgramSchema changeset (valid)**: Full schedule fields accepted on valid input
- **ProgramSchema changeset (invalid day)**: `["Funday"]` rejected with `"contains invalid days: Funday"`
- **ProgramSchema changeset (unpaired times)**: Start without end rejected: `"both start and end times must be set together"`
- **ProgramSchema changeset (end before start time)**: Rejected: `"must be after start time"`
- **ProgramSchema changeset (end date before start)**: Rejected: `"must be before end date"`
- **Domain Model `Program.create/1` (valid)**: Returns `{:ok, %Program{}}`
- **Domain Model `Program.create/1` (invalid day)**: Returns `{:error, ["meeting_days contains invalid weekday names"]}`
- **Domain Model `Program.create/1` (unpaired time)**: Returns `{:error, ["both meeting_start_time and meeting_end_time must be set together"]}`
- **Domain Model `Program.create/1` (end before start)**: Returns `{:error, ["meeting_end_time must be after meeting_start_time"]}`
- **Domain Model `Program.create/1` (end date before start)**: Returns `{:error, ["start_date must be before end_date"]}`
- **ProgramPresenter `format_schedule/1`**: Full data returns `%{days: "Mon, Wed & Fri", times: "4:00 - 5:30 PM", date_range: "Mar 1 - Jun 30, 2026"}`
- **ProgramPresenter `format_schedule/1`**: Cross-year returns `"Nov 1, 2026 - Mar 15, 2027"`
- **ProgramPresenter `format_schedule/1`**: Open-ended returns `"From Mar 1, 2026"`
- **ProgramPresenter `format_schedule/1`**: No data returns `nil`
- **ProgramPresenter `format_schedule_brief/1`**: Two days: `"Tue & Thu 4:00 - 5:30 PM"`
- **ProgramPresenter `format_schedule_brief/1`**: Single day: `"Sat 4:00 - 5:30 PM"`
- **ProgramPresenter `format_schedule_brief/1`**: AM-PM cross: `"Mon, Wed & Fri 11:00 AM - 1:00 PM"`
- **ProgramMapper round-trip**: `to_domain` and `to_schema` preserve all scheduling fields correctly
- **Server logs**: No warnings or errors related to scheduling changes

### Issues Found
- None

## UI Checks

### Pages Tested
- `/provider/dashboard/programs` (form): **PASS**
  - Schedule section present with "Schedule (optional)" label
  - 7 day checkboxes (Mon-Sun) displayed correctly
  - Start/end time pickers present
  - Start/end date pickers present
  - Form opens correctly via "New Program" button
- `/programs` (listing): **PASS**
  - Program card for "Soccer Fundamentals" shows `"Mon, Wed & Fri 4:00 - 5:30 PM"` (tested with injected data)
  - Programs without schedule data show clock icon with no text (empty brief format)
- `/programs/:id` (detail with schedule): **PASS**
  - Hero shows `"Mon, Wed & Fri · 4:00 - 5:30 PM"` with middle-dot separator
  - Days and times formatted correctly in 12-hour format
- `/programs/:id` (detail without schedule): **PASS**
  - Shows "Schedule TBD" fallback correctly
- Mobile (375x667): **PASS**
  - Provider form: day checkboxes wrap naturally, time/date inputs in 2-column grid
  - Program detail: schedule displays cleanly in hero section

### Issues Found
- **[info]**: Console shows SVG `<path>` errors for icon images across all pages. Pre-existing issue, not related to this branch.

## Auto-Fixes Applied
- None needed

## Recommendations
- None - all scheduling changes verified end-to-end successfully
