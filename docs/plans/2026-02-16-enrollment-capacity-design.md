# Enrollment Capacity Design

**Issue:** GH #149 / beads prime-youth-67d
**Date:** 2026-02-16
**Status:** Approved

## Problem

Providers need to set min/max enrollment for programs. Currently `spots_available` lives on Program (catalog context) but is never maintained — no code decrements it on enrollment. Capacity enforcement belongs in the enrollment context.

## Decisions

1. **Enrollment context owns capacity** — new `EnrollmentPolicy` domain model
2. **Remove `spots_available` from Program** — it's a misleading denormalized field with no maintainer
3. **ACL for catalog display** — catalog queries enrollment context for remaining capacity (no events yet)
4. **Drop-in toggle deferred** — awaiting PM clarification
5. **Min enrollment: warning + provider action** — no auto-cancel

## Architecture

### Domain Layer (Enrollment Context)

**EnrollmentPolicy** — new aggregate, one per program:
- `id`, `program_id` (unique), `min_enrollment` (optional int >= 1), `max_enrollment` (optional int >= 1)
- Invariant: if both set, min <= max
- At least one of min/max should be set

**Port: ForManagingEnrollmentPolicies**
- `upsert(attrs)` — create or update policy
- `get_by_program_id(program_id)` — fetch policy
- `get_remaining_capacity(program_id)` — max - count(active enrollments), or `:unlimited`

**CreateEnrollment changes:**
- Before creating: load policy, count active enrollments, reject if count >= max
- New error: `{:error, :program_full}`

### Program Catalog Changes

- Remove `spots_available` field from Program domain model and schema
- Remove `sold_out?/1` helper
- New ACL module: `ProgramCatalog.EnrollmentCapacityACL` — calls enrollment context for remaining capacity

### Persistence

**New table: `enrollment_policies`**
```sql
id              : binary_id (PK)
program_id      : references(programs), unique, not null
min_enrollment  : integer, nullable  (CHECK >= 1)
max_enrollment  : integer, nullable  (CHECK >= 1)
                                     (CHECK min <= max when both set)
inserted_at     : utc_datetime_usec
updated_at      : utc_datetime_usec
```

**Migration strategy:**
1. Create `enrollment_policies` table
2. Migrate existing `spots_available > 0` rows into enrollment_policies as max_enrollment
3. Remove `spots_available` column from programs

**Capacity query:**
```sql
SELECT ep.max_enrollment - COUNT(e.id) AS remaining
FROM enrollment_policies ep
LEFT JOIN enrollments e ON e.program_id = ep.program_id
  AND e.status IN ('pending', 'confirmed')
WHERE ep.program_id = $1
GROUP BY ep.max_enrollment
```

### LiveView Changes

**Provider form** (`provider_components.ex`, `dashboard_live.ex`):
- Add min/max enrollment fields in "Enrollment Capacity" section
- On save: call ProgramCatalog.create_program, then Enrollment.set_enrollment_policy
- Same two-call pattern for updates

**BookingLive:**
- Replace `validate_program_availability/1` (was checking `spots_available`)
- New check: `Enrollment.remaining_capacity(program_id)`
- Display remaining spots to parent
- Block enrollment when remaining = 0

**Program listings:**
- Use ACL to display "X spots left" / "Full" badge on program cards

**Provider dashboard — min enrollment warning:**
- Show warning on programs where registration closed AND enrollment count < min
- Informational only, no automated action

## Out of Scope

- Drop-in toggle (awaiting PM input)
- Event-driven capacity updates (ACL is sufficient for now)
- Waitlist functionality
- Per-session capacity (programs have flat enrollment)
