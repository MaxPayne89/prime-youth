# Admin Bookings Design

**Issue:** #340 — Add Bookings to Admin Dashboard
**Date:** 2026-03-10
**Status:** Approved

## Summary

Add a read-only Backpex resource for bookings (enrollments) to the admin dashboard, with a cancel item action that goes through a proper use case. Follows the established pattern of UserLive, ProviderLive, and StaffLive.

## Approach

**Backpex resource + custom item action.** The listing, filtering, search, pagination, and sorting come from Backpex. The cancel workflow uses a Backpex item action that calls a dedicated use case, keeping business logic in the domain layer.

This differs from ProviderLive (which edits fields directly via Backpex and bridges back with events) because enrollment status transitions carry business logic (lifecycle guards, capacity implications) that belong in a use case.

## Schema Changes

### EnrollmentSchema

Add three `belongs_to` associations for Backpex display. The existing `field :program_id/:child_id/:parent_id, :binary_id` lines are replaced — `belongs_to` defines the FK fields implicitly.

```elixir
belongs_to :program, KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
belongs_to :child, KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildSchema
belongs_to :parent, KlassHero.Family.Adapters.Driven.Persistence.Schemas.ParentProfileSchema,
  foreign_key: :parent_id,
  references: :id
```

Add `admin_changeset/3` (required by Backpex even when edit is disabled):

```elixir
def admin_changeset(schema, _attrs, _metadata), do: change(schema)
```

No migration needed — DB columns and constraints already exist.

**Impact on existing code:** The `create_changeset` and `update_changeset` functions continue to cast `program_id`/`child_id`/`parent_id` as before. The repository and mapper code that uses these fields by name is unaffected — Ecto associations are additive metadata.

## BookingLive Backpex Resource

**Module:** `KlassHeroWeb.Admin.BookingLive`

### Permissions

| Action | Allowed |
|--------|---------|
| `:index` | yes |
| `:show` | yes |
| `:new` | no |
| `:edit` | no |
| `:delete` | no |

### Fields

| Field | Type | Index | Show | Searchable | Orderable | Notes |
|-------|------|-------|------|------------|-----------|-------|
| Program | BelongsTo | yes | yes | yes | yes | display_field: `:title` |
| Child | BelongsTo | yes | yes | yes | no | display_field: `:first_name`, custom render for full name |
| Parent | BelongsTo | yes | yes | yes | no | display_field: `:display_name` |
| Status | Text | yes | yes | no | yes | Custom render: color-coded badges |
| Total amount | Text | yes | yes | no | yes | Custom render: currency format |
| Payment method | Text | no | yes | no | no | |
| Enrolled at | DateTime | yes | yes | no | yes | |
| Special requirements | Textarea | no | yes | no | no | |
| Cancellation reason | Text | no | yes | no | no | |
| Confirmed at | DateTime | no | yes | no | no | |
| Cancelled at | DateTime | no | yes | no | no | |

### Filter

`StatusFilter` — Boolean-style multi-select with options: pending, confirmed, completed, cancelled. Follows the ActiveFilter/VerifiedFilter pattern.

### Init Order

`enrolled_at` descending.

### Route

```elixir
live_resources("/bookings", BookingLive, only: [:index, :show])
```

Added to the `:backpex_admin` live_session in the router.

## Cancel Item Action

**Module:** `KlassHeroWeb.Admin.Actions.CancelBookingAction`

### UX

- Button visible only when status is `pending` or `confirmed`
- Opens a confirmation modal with:
  - Warning: "This will free the reserved slot and cannot be undone."
  - Required text input for cancellation reason

### Execution Flow

1. Admin clicks "Cancel" on a booking row
2. Modal opens with warning + reason field
3. Admin enters reason, confirms
4. Action calls `Enrollment.cancel_enrollment_by_admin(enrollment_id, admin_id, reason)`
5. On success: Backpex refreshes the list
6. On failure (invalid transition): flash error message

## Port & Repository Addition

The `ForManagingEnrollments` port and `EnrollmentRepository` currently have no `update` callback. The cancel use case needs to persist status changes.

**Port:** Add `@callback update(String.t(), map()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}` to `ForManagingEnrollments`.

**Repository:** Add `update/2` to `EnrollmentRepository` that loads the record, applies `EnrollmentSchema.update_changeset/2`, and calls `Repo.update/1`.

## Use Case — CancelEnrollmentByAdmin

**Module:** `KlassHero.Enrollment.Application.UseCases.CancelEnrollmentByAdmin`

**Input:** `enrollment_id`, `admin_id`, `reason` (reason is required at the use case level)

**Flow:**

1. Load enrollment via `ForManagingEnrollments.get_by_id/1`
2. Map to domain model via `EnrollmentMapper.to_domain/1`
3. Call `Enrollment.cancel(enrollment, reason)` — enforces lifecycle guards
4. Map back to persistence attrs, update via `ForManagingEnrollments.update/2`
5. Dispatch `enrollment_cancelled` domain event with `admin_id` in payload
6. Return `{:ok, enrollment}` or `{:error, reason}`

**Facade:** `KlassHero.Enrollment.cancel_enrollment_by_admin(enrollment_id, admin_id, reason)`

## Domain Events

### Domain Event

New factory function in `EnrollmentEvents`:

```elixir
def enrollment_cancelled(enrollment_id, payload, opts \\ [])
# payload: %{
#   enrollment_id, program_id, child_id, parent_id,
#   admin_id, reason, cancelled_at
# }
```

### Integration Event

New factory function in `EnrollmentIntegrationEvents` with `entity_type: :enrollment`:

```elixir
@source_context :enrollment

def enrollment_cancelled(enrollment_id, payload, opts \\ [])
# entity_type: :enrollment (not the module default :participant_policy)
```

Promoted by the existing `PromoteIntegrationEvents` handler (add a new clause for `:enrollment_cancelled`). No consumers yet — the event is in place for future parent notifications, audit logging, and analytics.

## Files Changed

| File | Change |
|------|--------|
| `enrollment/adapters/.../schemas/enrollment_schema.ex` | Add `belongs_to` associations + `admin_changeset/3` |
| `lib/klass_hero_web/router.ex` | Add bookings route to `:backpex_admin` |
| `lib/klass_hero_web/live/admin/booking_live.ex` | **New** — Backpex resource |
| `lib/klass_hero_web/live/admin/actions/cancel_booking_action.ex` | **New** — Item action |
| `lib/klass_hero_web/live/admin/filters/status_filter.ex` | **New** — Status filter |
| `enrollment/application/use_cases/cancel_enrollment_by_admin.ex` | **New** — Use case |
| `enrollment/domain/events/enrollment_events.ex` | Add `enrollment_cancelled/3` |
| `enrollment/domain/events/enrollment_integration_events.ex` | Add `enrollment_cancelled/3` |
| `enrollment/domain/ports/for_managing_enrollments.ex` | Add `update/2` callback |
| `enrollment/adapters/.../repositories/enrollment_repository.ex` | Implement `update/2` |
| `enrollment/adapters/.../events/event_handlers/promote_integration_events.ex` | Handle `:enrollment_cancelled` event |
| `lib/klass_hero/enrollment.ex` | Add `cancel_enrollment_by_admin/3` facade function |

## Tests

| File | Coverage |
|------|----------|
| `test/klass_hero/enrollment/application/use_cases/cancel_enrollment_by_admin_test.exs` | Use case: success, invalid transition, not found |
| `test/klass_hero_web/live/admin/booking_live_test.exs` | Index listing, show detail, cancel action flow |
| `test/klass_hero/enrollment/domain/events/enrollment_events_test.exs` | Update: add `enrollment_cancelled` factory test |
| `test/klass_hero/enrollment/domain/events/enrollment_integration_events_test.exs` | Update: add `enrollment_cancelled` factory test |

## Not In Scope

- Expire/retry workflows (deferred)
- Bulk actions
- CSV export
- Revenue analytics
- Edit capabilities (all mutations are through the cancel action only)
