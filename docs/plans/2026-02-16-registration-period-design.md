# Registration Period Configuration

**Issue:** #147
**Date:** 2026-02-16
**Approach:** Embedded Value Object (RegistrationPeriod)

## Domain Layer

### RegistrationPeriod Value Object

**File:** `lib/klass_hero/program_catalog/domain/models/registration_period.ex`

Pure struct with `start_date` (Date.t | nil) and `end_date` (Date.t | nil).

**Functions:**

| Function | Returns | Behavior |
|----------|---------|----------|
| `new/1` | `{:ok, t()} \| {:error, [String.t()]}` | Validates start < end when both present. Either/both can be nil. |
| `status/1` | `:always_open \| :upcoming \| :open \| :closed` | nil/nil = always_open. Before start = upcoming. Between = open. After end = closed. Only start + past it = open. Only end + before it = open. |
| `open?/1` | `boolean()` | `status(rp) in [:always_open, :open]` |

### Program Struct Changes

- Add `registration_period: RegistrationPeriod.t()` with default `%RegistrationPeriod{}`
- Add to `@updatable_fields`
- `create/1` builds RegistrationPeriod from flat `registration_start_date` / `registration_end_date` attrs

## Persistence Layer

### Migration

Two nullable date columns on `programs`: `registration_start_date`, `registration_end_date`.

### ProgramSchema

- Add both fields, add to cast lists in all three changesets
- Add `validate_registration_date_range/1` (same pattern as `validate_date_range/1`)

### ProgramMapper

- `to_domain/1`: assemble RegistrationPeriod from flat columns
- `to_schema/1`: destructure back to flat columns

## Web Layer

### BookingLive — Registration Gate

- New `validate_registration_open/1` step in mount's `with` chain (before availability check)
- Same check in `complete_enrollment` handler (race condition guard)
- `{:error, :registration_not_open}` → flash + redirect to program detail page

### ProgramDetailLive — Status Display

- Derive `registration_status` assign in mount via `RegistrationPeriod.status/1`
- Status banner (using existing `<.info_box>`):
  - `:upcoming` → "Registration opens [date]"
  - `:closed` → "Registration is closed"
  - `:open` / `:always_open` → no banner (or subtle "closes [date]" if end_date set)
- Book Now button: disabled with changed text when not open

### Provider Dashboard — Form Inputs

- Two `<.input type="date">` fields for registration start/end dates
- Grouped under "Registration Period" section, separate from Schedule
- Helper hint: "Leave blank for open registration"
- No new components or context API changes

## Testing

- **RegistrationPeriod unit tests**: new/1 validation, status/1 all four states, open?/1
- **ProgramSchema**: validate_registration_date_range changeset tests
- **ProgramMapper**: round-trip flat dates ↔ value object
- **BookingLive**: mount redirect when registration not open, happy path when open
- **ProgramDetailLive**: banner rendering per status, button disabled state
- **Provider dashboard**: form accepts dates, persists, shows on edit

## Decisions

- **Registration dates optional** — nil/nil means always open (least friction for providers)
- **Program Catalog owns the concept** — Enrollment context unchanged
- **Gate in web layer** — BookingLive checks `RegistrationPeriod.open?/1`, not Enrollment
- **Visible but disabled** — closed programs show full details, disabled Book Now button with status message
