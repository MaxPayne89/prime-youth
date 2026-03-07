# Design: Delete Child with Active Enrollments

> **Issue:** #298 — Parent can't delete a child who has active enrollments.
>
> **Root cause:** `DeleteChild` use case only cleans up consents before deletion. Enrollments and participation records have FK RESTRICT constraints that block the DELETE.

## Approach: Synchronous ACL Adapters within Family

Family's `DeleteChild` use case uses ACL (Anti-Corruption Layer) adapters that query enrollment and participation tables directly via raw Ecto queries. This avoids a dependency cycle (Enrollment already depends on Family) while keeping all cleanup within Family's transaction. No saga, no async events — all contexts share `KlassHero.Repo`, so the ACL queries automatically participate in Family's open transaction.

## Changes by Context

### Enrollment Context

No changes. Family's `ChildEnrollmentACL` adapter queries the `enrollments` and `programs` tables directly to avoid coupling.

### Participation Context

No changes. Family's `ChildParticipationACL` adapter queries the `participation_records` and `behavioral_notes` tables directly.

### Family Context

**New ACL adapters** (in `family/adapters/driven/acl/`):

**`ChildEnrollmentACL`** — implements `ForManagingChildEnrollments` port:
- `list_active_with_program_titles/1` — returns active enrollments with program names via direct table join
- `cancel_active_for_child/1` — bulk-updates active enrollments to "cancelled"

**`ChildParticipationACL`** — implements `ForManagingChildParticipation` port:
- `delete_records_for_child/1` — hard-deletes participation records and behavioral notes

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
- No additional migration changes beyond making `enrollments.child_id` nullable with FK `ON DELETE: :nilify_all`; all other FK constraints remain `RESTRICT`
- No soft-delete for children
- No changes to enrollment status enum ("cancelled" already exists)

## Test Coverage

- `DeleteChild` with active enrollments: enrollments cancelled, participation deleted, child removed
- `DeleteChild` with no enrollments: works as before
- `PrepareChildDeletion` with/without enrollments: correct return values
- LiveView: modal shown when enrollments exist, direct delete when none
