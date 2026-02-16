# Test Drive Report - 2026-02-16

## Scope
- Mode: branch (main...HEAD)
- Files changed: 17
- Routes affected: `/programs/:id` (detail), `/programs/:id/booking`, `/provider/dashboard/programs` (form)

## Backend Checks

### Passed
- Migration: `registration_start_date` and `registration_end_date` columns exist on `programs` table (nullable date)
- `RegistrationPeriod.new/1`: valid dates accepted, start >= end rejected, nil dates produce always_open
- `RegistrationPeriod.status/1`: all 8 permutations correct (nil/nil=always_open, future/far_future=upcoming, past/future=open, past/past=closed, past_start/nil=open, future_start/nil=upcoming, nil/future_end=open, nil/past_end=closed)
- `Program.registration_open?/1`: delegates correctly for open (true), closed (false), always_open (true)
- `Program.registration_status/1`: returns correct status atoms
- `Program.create/1`: builds RegistrationPeriod from flat `registration_start_date`/`registration_end_date` attrs
- Mapper round-trip: schema with dates maps to domain model with populated `registration_period`; nil dates map to empty struct
- Changeset validation: `ProgramSchema.create_changeset/2` rejects start >= end with error `"must be before registration end date"`
- All 186 tests pass (0 failures)

### Issues Found
- None

## UI Checks

### Pages Tested
- `/programs/:id` (Youth Fitness Basics, always_open): **pass**
  - No registration banner displayed
  - "Book Now" button enabled
  - "Enroll Now" bottom CTA enabled
  - Screenshot: `test-drive-default-desktop.png`

- `/programs/:id` (Sports Camp, upcoming): **pass**
  - Banner: "Registration opens February 21, 2026" with calendar icon
  - "Registration Not Open Yet" button disabled
  - Bottom CTA also disabled
  - Screenshot: `test-drive-upcoming-desktop.png`

- `/programs/:id` (Junior Athletics, closed): **pass**
  - Banner: "Registration is closed" with lock icon
  - "Registration Closed" button disabled
  - Bottom CTA also disabled
  - Screenshot: `test-drive-closed-desktop.png`

- `/programs/:id` (Basketball Skills, open): **pass**
  - No registration banner (same as always_open)
  - "Book Now" button enabled
  - "Enroll Now" bottom CTA enabled

- Mobile (375x667) upcoming state: **pass**
  - Banner visible and readable
  - Sticky footer shows "Registration Not Open Yet" (disabled)
  - Layout intact, no overflow
  - Screenshot: `test-drive-mobile-upcoming.png`

- Mobile (375x667) open state: **pass**
  - "Book Now" enabled in both card and sticky footer
  - Layout intact
  - Screenshot: `test-drive-mobile-open.png`

- `/provider/dashboard/programs` — New Program form: **pass**
  - "Registration Period (optional)" section visible
  - Helper text: "Leave blank for open registration at any time."
  - "Registration Opens" and "Registration Closes" date inputs present
  - Screenshot: `test-drive-provider-form.png`

- Booking gate (`/programs/:id/booking`): **not fully testable**
  - Current session is provider role, redirects to provider dashboard
  - Registration gate logic covered by unit tests

### Issues Found
- None

## Auto-Fixes Applied
- None needed

## Recommendations
- None — feature is clean and complete

## Pre-existing Issue (Not Related)
- **info**: `column p0.schedule does not exist` error on home page (`list_all_programs` query) — pre-existing schema mismatch, not introduced by this branch
