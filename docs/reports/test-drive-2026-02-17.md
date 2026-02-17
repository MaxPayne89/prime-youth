# Test Drive Report: Enrollment Capacity Branch

**Date:** 2026-02-17
**Branch:** `feat/149-add-enrollment-capacity`
**Test suite:** 2177 tests, 0 failures, 5 skipped

## Backend Verification (Tidewave)

| Check | Result | Notes |
|-------|--------|-------|
| `enrollment_policies` table exists | PASS | Columns: id, program_id, min_enrollment, max_enrollment, inserted_at, updated_at |
| `spots_available` removed from programs | PASS | Migration `20260216192807` ran successfully (was pending in dev) |
| EnrollmentPolicySchema changeset: valid attrs | PASS | min=5, max=20 produces valid changeset |
| EnrollmentPolicySchema changeset: min > max | PASS | Rejected with `"must not exceed maximum enrollment"` |
| EnrollmentPolicySchema changeset: both nil | PASS | Valid at schema level (domain handles this) |
| EnrollmentPolicyRepository.upsert: create | PASS | `{:ok, schema}` returned |
| EnrollmentPolicyRepository.upsert: update existing | PASS | `{:ok, schema}` with updated min=5, max=25 |
| Enrollment.remaining_capacity/1: with policy | PASS | Returns `{:ok, 25}` |
| Enrollment.remaining_capacity/1: no policy | PASS | Returns `{:ok, :unlimited}` |
| Enrollment.get_remaining_capacities/1: batch | PASS | Returns correct map of program_id => remaining |
| ProgramCatalog.remaining_capacities/1: ACL | PASS | Delegates correctly to Enrollment context |
| ProgramPresenter.to_table_view/2: with data | PASS | `%{enrolled: 3, capacity: 25}` |
| ProgramPresenter.to_table_view/2: without data | PASS | `%{enrolled: nil, capacity: nil}` |
| BookingLive.validate_program_capacity | PASS | Handles `:unlimited`, positive remaining, and zero (`:program_full`) |
| CreateEnrollment: create_with_capacity_check | PASS | Uses SELECT FOR UPDATE, returns `:program_full` when at capacity |

## UI Verification (Playwright)

| Check | Result | Notes |
|-------|--------|-------|
| Provider dashboard: enrollment capacity fields visible | PASS | "Minimum Enrollment" and "Maximum Enrollment" spinbuttons present |
| Create program with valid capacity (min=5, max=30) | PASS | Success flash, table shows "0/30" |
| Create program without capacity | N/T | Not tested (slots limited) |
| Create program with min > max | PASS | Warning flash: "Program created, but enrollment capacity could not be saved." |
| Programs table: enrollment column | PASS | Shows "0/12", "0/15", "0/20", "0/30" correctly |
| Programs listing (/programs) | PASS | Renders without functional errors |
| Program detail: "Only X spots left!" badge | PASS | Badge removed as expected |
| Booking page: unlimited capacity access | N/T | Not tested (provider account, not parent) |
| Mobile responsive (375px) | PASS | Dashboard renders correctly; enrollment column truncated but scrollable |

## Bug Found & Fixed

**Phantom capacity display on failed enrollment policy save**

- **Location:** `dashboard_live.ex:501-506`
- **Symptom:** When creating a program with min > max (invalid policy), the program table showed "0/5" (the max value from the rejected form) instead of "—/—"
- **Root cause:** `new_enrollment_data` was built from form params unconditionally, regardless of whether the policy was actually persisted
- **Fix:** Conditionally set capacity to `nil` when `policy_result` is `{:error, _}`

```elixir
# Before (bug):
max = parse_integer(enrollment_params["max_enrollment"])
new_enrollment_data = %{program.id => %{enrolled: 0, capacity: max}}

# After (fix):
capacity = case policy_result do
  :ok -> parse_integer(enrollment_params["max_enrollment"])
  {:error, _} -> nil
end
new_enrollment_data = %{program.id => %{enrolled: 0, capacity: capacity}}
```

## Notes

- Dev DB migration `20260216192807` was pending — ran during test drive
- SVG path errors in console on `/programs` page are cosmetic (icon file issues), not related to this branch
- The `enrollment_policies` table has a unique constraint on `program_id` supporting the upsert pattern
