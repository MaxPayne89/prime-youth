# PR Review Findings: bug/195-enrollment-total-price

**Date:** 2026-03-03
**Branch:** worktree-bug/195-enrollment-total-price
**Reviewers:** architecture, test-coverage, silent-failure, code-simplifier agents

---

## Critical (1)

### 1. Silent nil fallback on `program.price` masks data corruption
**File:** `booking_live.ex:23`

`program.price || Decimal.new("0.00")` silently makes a paid program appear free. Price is `NOT NULL` in DB and `@enforce_keys` in domain model — nil here means a bug. Should raise or redirect with error.

---

## Important (4)

### 2. Hardcoded zero `subtotal` creates inconsistent persisted data
**File:** `booking_live.ex:263`

`subtotal: Decimal.new("0.00")` while `total_amount` holds the real price. Set `subtotal = total_amount` so `subtotal + vat + card_fee == total` holds true.

### 3. Missing `{:error, :duplicate_resource}` handler (pre-existing)
**File:** `booking_live.ex:126-201`

Double-submit or concurrent enrollment of same child crashes LiveView. Needs catch-all error clause.

### 4. Stale `@total` in commented-out bank transfer block
**File:** `booking_live.ex:507`

Uses deleted `@total` assign. Will crash if uncommented. Update or remove block.

### 5. Enrollment context README references removed fee calculation
**File:** `docs/contexts/enrollment/README.md` lines 2, 7, 9, 18, 86, 115, 135-136

FeeCalculation model, feature row, ubiquitous language — all stale.

---

## Suggestions (7)

### 6. Use `format_price` instead of `Decimal.to_string` in template
**Files:** `booking_live.ex:348,489,493`

`Decimal.to_string` doesn't guarantee 2 decimal places. Use `ProgramCatalog.format_price(@total_amount)` for consistent output.

### 7. `ProgramPricing` moduledoc says "calculation logic"
**File:** `program_pricing.ex:3`

Only formatting remains. Minor wording fix.

### 8. `Enrollment` facade moduledoc example shows derived fee amounts
**File:** `enrollment.ex:12-19`

Example should reflect zeroed fees with `total_amount = program.price`.

### 9. "Avoid card fees" payment description is misleading
**File:** `booking_live.ex:477`

No card fees exist but text implies a cost difference.

### 10. `booking_summary` component has dead slots
**File:** `booking_components.ex:116-161`

`:subtotal` slot and `:after_subtotal` attribute unused. Follow-up cleanup.

### 11. Program catalog README says "price x 4 weeks"
**File:** `docs/contexts/program-catalog/README.md:71`

Stale after removing weekly multiplication.

### 12. No test for nil price handling
If nil handling is kept (or changed to raise), it should be tested.

---

## Test Gaps

| Priority | Gap | Criticality |
|----------|-----|-------------|
| 1 | No test for nil price handling | 9/10 |
| 2 | No assertion that persisted enrollment has correct `total_amount` | 8/10 |
| 3 | No `ProgramDetailLive` test for pricing display consistency | 6/10 |

---

## Architecture Compliance: PASS

All 8 DDD/Ports & Adapters criteria passed. No cross-context violations, correct dependency direction, clean facade APIs.
