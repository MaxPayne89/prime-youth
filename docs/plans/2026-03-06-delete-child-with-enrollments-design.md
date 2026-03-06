# Design: Delete Child with Active Enrollments

> **Issue:** #298 — Parent can't delete a child who has active enrollments.
>
> **Root cause:** `DeleteChild` use case only cleans up consents before deletion. Enrollments and participation records have FK RESTRICT constraints that block the DELETE.

## Approach: Synchronous ACL via Public API Facades

Family's `DeleteChild` use case calls Enrollment and Participation public APIs within a single transaction to clean up cross-context records before deleting the child. No saga, no async events — all contexts share `KlassHero.Repo`, so SQL operations from other contexts automatically participate in Family's open transaction.

## Changes by Context

### Enrollment Context

Two new public API functions:

**`Enrollment.cancel_enrollments_for_child/1`**
- Bulk-updates active enrollments (pending/confirmed) to status "cancelled" for a given child_id
- New use case: `CancelEnrollmentsForChild`
- New repo port function on the enrollment repository port
- Returns `{:ok, cancelled_count}`
- No transaction wrapping — caller coordinates

**`Enrollment.list_active_enrollments_for_child/1`**
- Returns active enrollments for a child with program names (via SQL join)
- Used by Family's `PrepareChildDeletion` use case for the confirmation modal
- Returns `[%{enrollment_id, program_id, program_name, status}]`

### Participation Context

**`Participation.delete_records_for_child/1`**
- Hard-deletes all participation records for a given child_id
- Behavioral notes cascade automatically (FK `ON DELETE: delete_all` on `participation_record_id`)
- New use case: `DeleteRecordsForChild`
- New repo port function on the participation repository port
- Returns `{:ok, deleted_count}`
- No transaction wrapping — caller coordinates

Why hard-delete: participation records (check-in/out timestamps) have no meaningful "cancelled" state.

### Family Context

**Updated `DeleteChild.execute/1`** — enhanced transaction:

```
Repo.transaction do
  1. Delete consents                (Family's own — existing)
  2. Cancel enrollments             (ACL -> Enrollment.cancel_enrollments_for_child/1)
  3. Delete participation records   (ACL -> Participation.delete_records_for_child/1)
  4. Delete child                   (Family's own — existing)
end
```

**New `PrepareChildDeletion.execute/1`** — pre-deletion check:

```
PrepareChildDeletion.execute(child_id)
  -> calls Enrollment.list_active_enrollments_for_child(child_id)
  -> returns {:ok, :no_enrollments} | {:ok, :has_enrollments, program_names}
```

**Boundary config:** Add `KlassHero.Enrollment` and `KlassHero.Participation` to Family's deps.

### LiveView (ChildrenLive)

Two-step delete flow replacing the browser `data-confirm`:

1. Delete button fires `"request_delete_child"` (renamed from `"delete_child"`)
2. LiveView checks ownership, calls `Family.prepare_child_deletion(child_id)`
3. `:no_enrollments` -> delete immediately via `Family.delete_child/1`
4. `:has_enrollments` -> show confirmation modal listing program names
5. User confirms in modal -> fires `"confirm_delete_child"` -> calls `Family.delete_child/1`

New assigns: `delete_candidate` (child being considered), `enrolled_programs` (program names for modal).

## Non-Goals

- No new integration events (YAGNI — transaction cleans up all referencing contexts)
- No migration changes (FK constraints stay as RESTRICT)
- No soft-delete for children
- No changes to enrollment status enum ("cancelled" already exists)

## Test Coverage

- `DeleteChild` with active enrollments: enrollments cancelled, participation deleted, child removed
- `DeleteChild` with no enrollments: works as before
- `PrepareChildDeletion` with/without enrollments: correct return values
- LiveView: modal shown when enrollments exist, direct delete when none
