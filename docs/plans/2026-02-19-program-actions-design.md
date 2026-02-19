# Program Action Buttons Design

**Date:** 2026-02-19
**Issue:** #145 — Program Actions
**Branch:** `bug/145-program-actions`

## Problem

The provider dashboard programs table has four action buttons (Preview, View Roster, Edit, Duplicate) that are visually present but functionally dead. This is misleading for providers.

## Scope

- **Preview** — wire up (navigation only)
- **Edit** — wire up (use case exists)
- **View Roster** — new backend + frontend (cross-context with ACL)
- **Duplicate** — remove button entirely (not needed now)

---

## 1. Preview Button

**Behavior:** Navigates provider to existing public program detail page at `/programs/:program_id`.

**Implementation:** Replace dead `<.action_button>` with a `<.link navigate={~p"/programs/#{program.id}"}>` wrapped action button. No event handler, no backend changes.

---

## 2. Edit Button

**Behavior:** Opens the same modal used for program creation, pre-populated with current program data.

**Implementation:**
- Add `phx-click="edit_program"` + `phx-value-id` to button
- Event handler fetches program via `ProgramCatalog.get_program(id)`, builds form with `to_form/2`, opens modal with `:edit` flag
- Modal submit checks flag: `:new` → `CreateProgram`, `:edit` → `UpdateProgram`
- `UpdateProgram` already handles optimistic locking via `lock_version`. Stale data → flash error.
- On success: close modal, update stream via `stream_insert`

**No new routes, ports, or use cases needed.**

---

## 3. View Roster Button

**Behavior:** Opens modal showing children enrolled in a program — child name, enrollment status (pending/confirmed), enrollment date.

### Backend — Enrollment Context

New pieces:

1. **Port callback** — add `list_by_program(program_id)` to `ForManagingEnrollments`
2. **Repository method** — `list_by_program/1` using existing `EnrollmentQueries.by_program/1`, filtered to active enrollments
3. **ACL port** — new `ForResolvingChildInfo` port in Enrollment's ports, speaking Enrollment's language (returns `%{id, name}` value objects, not Family domain types)
4. **ACL adapter** — implements `ForResolvingChildInfo` by calling `Family.get_children_by_ids/1` and translating to Enrollment-domain types
5. **Use case** — `ListProgramEnrollments.execute(program_id)` fetches enrollments, resolves child names via ACL, returns enriched roster
6. **Facade** — expose `Enrollment.list_program_enrollments/1`

### Backend — Family Context

- Add `get_children_by_ids/1` to Family public API (batch fetch by list of IDs)

### Frontend

- Add `phx-click="view_roster"` + `phx-value-id` to button
- Event handler calls `Enrollment.list_program_enrollments(program_id)`, assigns to socket
- New roster modal component: simple table with Child Name | Status | Enrolled Date
- Empty state when no enrollments

### Architecture Notes

- **ACL pattern:** Enrollment never sees Family domain types. The ACL adapter is the only coupling point.
- **Future migration path:** When moving to event-driven choreography, replace ACL adapter with a local projection (Enrollment stores denormalized child names populated by domain events). The use case and port remain unchanged — the ACL becomes the seam.

---

## 4. Remove Duplicate Button

Delete the Duplicate `<.action_button>` from the programs table component in `provider_components.ex`. No stub, no disabled state.

---

## Summary

| Button | Backend Work | Frontend Work | Complexity |
|--------|-------------|---------------|------------|
| Preview | None | Link navigation | Trivial |
| Edit | None (use case exists) | Event handler + modal reuse | Low |
| View Roster | New port, ACL, use case, repo method | Event handler + modal | Medium |
| Duplicate | None | Delete button | Trivial |
