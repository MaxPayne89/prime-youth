# Program Creation with Staff Assignment — Design

**Issue:** #45
**Date:** 2026-02-10

## Summary

Providers create programs from the dashboard Programs tab via an inline form panel (same pattern as staff member creation). Programs can optionally have an assigned instructor.

## UX Decisions

- **Form location:** Inline panel on the Programs tab (not a separate page)
- **Form layout:** Single panel with all fields visible at once
- **Fields (issue scope only):** Title, Category, Price, Location, Description, Cover Image, Assign Instructor
- **Existing fields not on form:** schedule, age_range, pricing_period, spots_available — made optional, can be added via future edit flow
- **Location:** Freeform text (not structured address)
- **Instructor:** One per program (simple FK, not many-to-many)
- **Gating:** "New Program" button disabled unless provider is verified (existing behavior)

## Domain Design

### Instructor Value Object (ACL)

ProgramCatalog defines its own `Instructor` value object (`id`, `name`, `headshot_url`). This is ProgramCatalog's representation of "who runs a program" — it never references Identity's `StaffMember` directly.

Populated at creation time: the web layer fetches the selected staff member from Identity, extracts display data, passes it to ProgramCatalog.

### Program Model Changes

- Relax `@enforce_keys` to `[:id, :title, :description, :category, :price]`
- Add fields: `location`, `cover_image_url`, `instructor` (Instructor VO)
- `provider_id` becomes enforced
- Existing optional fields (`schedule`, `age_range`, `pricing_period`, `spots_available`) stay on struct with nil/0 defaults

### Cross-Context Communication (Integration Events)

- ProgramCatalog publishes a **domain event** `program_created` internally
- A promotion handler converts it to an **integration event** published to `integration:program_catalog:program_created`
- Other contexts (Identity, etc.) can subscribe if needed
- ProgramCatalog does NOT call Identity — the web layer and DB FK handle validation

### Port: ForCreatingPrograms

New single-callback port: `create(attrs) :: {:ok, Program.t()} | {:error, term()}`

### Use Case: CreateProgram

Persists via port, publishes domain event. Does not call Identity.

## Persistence (High Level)

- Migration: add `location`, `cover_image_url`, `instructor_id` (FK to staff_members, on_delete: nilify), `instructor_name`, `instructor_headshot_url`
- ProgramSchema: add new fields, create changeset
- ProgramMapper: construct Instructor VO from flat DB columns
- ProgramRepository: implement `create/1`

## Deferred to Follow-Up Issues

- Staleness subscriber (update instructor display data when staff profile changes in Identity)
- Program editing flow
- Additional program fields on form (schedule, age_range, etc.)
