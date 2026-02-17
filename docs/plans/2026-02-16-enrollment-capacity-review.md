# Architecture Review: feat/149-add-enrollment-capacity

**Date:** 2026-02-16
**Branch:** feat/149-add-enrollment-capacity
**Scope:** 40 files, ~2,700 lines across Enrollment and Program Catalog contexts

---

## Critical Issues (3)

### 1. Silent failure: enrollment policy save error swallowed

**File:** `dashboard_live.ex:1213-1214`

`{:error, _} -> :ok` discards the error — provider sees "Program created!" but capacity was never saved. Provider thinks capacity is set, it isn't. Overbooking risk.

**Fix:** Propagate error, show flash warning to provider.

### 2. Race condition: capacity check + enrollment create not atomic

**File:** `create_enrollment.ex:60-68`

`validate_program_capacity` and `repository().create(attrs)` are separate DB operations. Two concurrent requests can both pass the check and exceed max_enrollment. Classic TOCTOU.

**Fix:** Wrap in transaction with `SELECT ... FOR UPDATE` or add DB-level constraint.

### 3. ACL placed in domain layer

**File:** `program_catalog/domain/services/enrollment_capacity_acl.ex`

ACL calls `KlassHero.Enrollment` facade from the domain layer — violates dependency direction (domain must be pure, no external context deps).

**Fix:** Move to `adapters/driven/` or `application/`.

---

## Important Issues (5)

### 4. Use case bypasses domain model

**File:** `create_enrollment.ex:133-147`

`validate_program_capacity` calls `policy_repo().get_remaining_capacity()` directly instead of using `EnrollmentPolicy.has_capacity?/2`. Domain model's capacity logic is dead code in production.

**Fix:** Load policy via port, delegate capacity decision to domain model.

### 5. Non-exhaustive pattern matches

**Files:** `create_enrollment.ex:133-147`, `booking_live.ex:218-224`

No error clause in capacity check `case` — if port contract evolves to return `{:error, _}`, crashes with `CaseClauseError`. Currently mitigated by Ecto raising on DB failures.

**Fix:** Add `{:error, _}` clause, consider extending port contract return type.

### 6. `parse_integer/1` silently drops invalid input

**File:** `dashboard_live.ex:1222-1225`

Values like "0", "-5", "abc" → nil with no user feedback. Both fields invalid → no policy created silently. Provider thinks capacity is "0" (closed), program actually unlimited.

**Fix:** Show validation errors for invalid numeric values.

### 7. N+1 queries in ProgramsLive

**File:** `programs_live.ex:136-140`

`get_remaining_capacity` called per-program (up to 2 DB queries each). 50 programs = 100 extra queries. Also no error boundary — single DB hiccup crashes entire listing.

**Fix:** Batch query for capacity. Add error handling for graceful degradation.

### 8. ProgramPresenter hardcodes capacity to 0

**File:** `program_presenter.ex:52-53`

Provider dashboard table shows "0" capacity for all programs — misleading. Providers will wonder if settings were saved.

**Fix:** Show "N/A" or query actual data from enrollment context.

---

## Test Coverage Gaps (3)

### 9. BookingLive: no test for `:program_full` rejection

**File:** `booking_live_test.exs:50-58`

Empty placeholder test asserts nothing. Now implementable with enrollment policies. Need tests for:
- Mount with full program → redirect with error flash
- Submit when program became full between mount and submit

### 10. Provider Dashboard: no test for capacity form fields

**File:** `dashboard_program_creation_test.exs`

`min_enrollment`/`max_enrollment` fields never submitted in tests. Silent failure path (`{:error, _} -> :ok`) untested. Key scenarios:
- Both min and max → policy created
- Only max → policy with nil min
- Invalid (min > max) → current silent discard behavior

### 11. EnrollmentCapacityACL has no dedicated test

**File:** `enrollment_capacity_acl.ex`

Thin delegation, but it's the cross-context boundary. No test verifies wiring.

---

## Additional Suggestions

### 12. `get_remaining_capacity` mixes business logic into repository port

**File:** `for_managing_enrollment_policies.ex:27-30`

Capacity calculation (max - active count) inside the port. Should provide raw data; domain/use case performs calculation via `has_capacity?/2`. Related to issue #4.

### 13. Virtual fields leak enrollment concepts into ProgramSchema

**File:** `program_schema.ex:41-43`

`min_enrollment`/`max_enrollment` as virtual fields on ProgramSchema leaks enrollment into catalog persistence. Consider extracting params directly in LiveView.

### 14. Stale "sold out" filter tests

**File:** `programs_live_test.exs`

Tests reference "sold out" concepts but `spots_available` is gone. No new capacity check wired into filter logic. Tests may pass vacuously.

---

## Strengths

- Correct bounded context ownership — capacity moved to Enrollment
- Clean Ports & Adapters layering — port, repository, mapper, schema follow patterns
- Pure domain model — `EnrollmentPolicy` is plain struct, no infrastructure deps
- Config-based DI consistent with existing patterns
- Reversible data migration with proper up/down
- DB CHECK constraints mirror domain validation (defense in depth)
- Thorough domain + persistence tests
- Consistent literate programming style (Trigger/Why/Outcome)

---

## Recommended Priority

1. **Fix #1** — silent policy failure (data integrity bug)
2. **Fix #3** — move ACL out of domain layer
3. **Document #2** — race condition as known limitation; ideally fix with locking
4. **Add tests #9, #10** — booking rejection and capacity form fields
5. Items #4-8 as follow-up work
