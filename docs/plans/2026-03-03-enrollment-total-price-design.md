# Enrollment Total Price Fix

**Issue:** #195 — Enrollment page total price doesn't match provider's program price
**Date:** 2026-03-03

## Problem

Provider enters a total program price during program creation. The enrollment page:
1. Treats it as a weekly fee and multiplies by number of weeks
2. Adds a €25 registration fee
3. Adds 19% VAT
4. Adds €2.50 card processing fee

## Decision

Provider's price = what parent pays. No derived fees, no multiplication. All fee infrastructure removed until future requirements materialize (installment payments, provider-configurable fees).

## Data Flow

**Before:** `program.price → ×weeks → +registration → +VAT → +card_fee → total`
**After:** `program.price → total_amount`

## Changes

### Remove

- `CalculateEnrollmentFees` use case (`enrollment/application/use_cases/`)
- `FeeCalculation` domain model (`enrollment/domain/models/`)
- `Enrollment.calculate_fees/1` public API
- `calculate_weeks/2` from BookingLive
- `registration_fee`, `vat_rate`, `card_processing_fee` from `:booking` config
- Tests for `CalculateEnrollmentFees`

### Modify

- **BookingLive.mount/3** — assign `total_amount` directly from `program.price`. No weeks, no config fetch.
- **BookingLive template** — payment summary: one line (program fee) + total. Remove registration fee, VAT, card fee line items.
- **BookingLive.create_enrollment/2** — `subtotal`/`vat_amount`/`card_fee_amount` set to zero, `total_amount` = `program.price`.

### Keep

- Enrollment domain model fields (`subtotal`, `vat_amount`, `card_fee_amount`, `total_amount`) — forward compatibility
- EnrollmentSchema + migration — no DB changes
- Payment method selection — still relevant for future payment processing

## Template After

```
Program fee:     €{program.price}
─────────────────────────────────
Total due today: €{program.price}
```
