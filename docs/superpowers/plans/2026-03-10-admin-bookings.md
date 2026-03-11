# Admin Bookings Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only Backpex admin resource for bookings with a cancel item action backed by a proper domain use case.

**Architecture:** Backpex LiveResource for listing/showing enrollments with cross-context `belongs_to` associations for display. Cancel action calls through `CancelEnrollmentByAdmin` use case which enforces domain lifecycle guards and dispatches events. TDD throughout.

**Tech Stack:** Elixir/Phoenix, Backpex LiveResource, Ecto, ExUnit

**Spec:** `docs/superpowers/specs/2026-03-10-admin-bookings-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `lib/klass_hero/enrollment/application/use_cases/cancel_enrollment_by_admin.ex` | Use case: load, cancel via domain model, persist, dispatch event |
| `lib/klass_hero_web/live/admin/booking_live.ex` | Backpex resource: index + show for enrollments |
| `lib/klass_hero_web/live/admin/actions/cancel_booking_action.ex` | Backpex item action: cancel with reason modal |
| `lib/klass_hero_web/live/admin/filters/status_filter.ex` | Backpex boolean filter for enrollment status |
| `test/klass_hero/enrollment/application/use_cases/cancel_enrollment_by_admin_test.exs` | Use case tests |
| `test/klass_hero_web/live/admin/booking_live_test.exs` | Admin LiveView tests |

### Modified Files

| File | Change |
|------|--------|
| `lib/klass_hero/enrollment/domain/ports/for_managing_enrollments.ex` | Add `update/2` callback |
| `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_repository.ex` | Implement `update/2` |
| `lib/klass_hero/enrollment/adapters/driven/persistence/schemas/enrollment_schema.ex` | Add `belongs_to` associations + `admin_changeset/3` |
| `lib/klass_hero/enrollment/domain/events/enrollment_events.ex` | Add `enrollment_cancelled/3` |
| `lib/klass_hero/enrollment/domain/events/enrollment_integration_events.ex` | Add `enrollment_cancelled/3` |
| `lib/klass_hero/enrollment/adapters/driven/events/event_handlers/promote_integration_events.ex` | Handle `:enrollment_cancelled` |
| `lib/klass_hero/enrollment.ex` | Add `cancel_enrollment_by_admin/3` facade |
| `lib/klass_hero_web/router.ex` | Add bookings route |
| `test/klass_hero/enrollment/domain/events/enrollment_events_test.exs` | Add `enrollment_cancelled` tests |
| `test/klass_hero/enrollment/domain/events/enrollment_integration_events_test.exs` | Add `enrollment_cancelled` tests |
| `test/klass_hero/enrollment/adapters/driven/events/event_handlers/promote_integration_events_test.exs` | Add `:enrollment_cancelled` handler test |

---

## Chunk 1: Domain & Infrastructure Layer

### Task 1: Add `update/2` to Port and Repository

**Files:**
- Modify: `lib/klass_hero/enrollment/domain/ports/for_managing_enrollments.ex:108`
- Modify: `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_repository.ex:236`
- Test: `test/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_repository_test.exs`

- [ ] **Step 1: Write failing test for repository update**

```elixir
# In enrollment_repository_test.exs, add new describe block:

describe "update/2" do
  test "updates enrollment status and returns domain entity" do
    schema = insert(:enrollment_schema, status: "pending")

    attrs = %{
      status: "cancelled",
      cancelled_at: DateTime.utc_now() |> DateTime.truncate(:second),
      cancellation_reason: "Admin cancelled"
    }

    assert {:ok, enrollment} = EnrollmentRepository.update(schema.id, attrs)
    assert enrollment.status == :cancelled
    assert enrollment.cancellation_reason == "Admin cancelled"
    assert enrollment.cancelled_at != nil
  end

  test "returns not_found for nonexistent enrollment" do
    assert {:error, :not_found} = EnrollmentRepository.update(Ecto.UUID.generate(), %{status: "cancelled"})
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_repository_test.exs --max-failures 1`
Expected: FAIL — `EnrollmentRepository.update/2` is undefined

- [ ] **Step 3: Add callback to port**

Add to `lib/klass_hero/enrollment/domain/ports/for_managing_enrollments.ex` after line 108:

```elixir
@doc """
Updates an existing enrollment by ID.

Returns:
- `{:ok, Enrollment.t()}` - Enrollment updated successfully
- `{:error, :not_found}` - No enrollment exists with the given ID
- `{:error, changeset}` - Validation failure
"""
@callback update(id :: binary(), attrs :: map()) ::
            {:ok, Enrollment.t()} | {:error, :not_found | term()}
```

- [ ] **Step 4: Implement `update/2` in repository**

Add to `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_repository.ex` before the final `end`:

```elixir
@impl true
@doc """
Updates an existing enrollment in the database.

Returns:
- `{:ok, Enrollment.t()}` on success
- `{:error, :not_found}` when enrollment doesn't exist
- `{:error, changeset}` on validation failure
"""
def update(id, attrs) when is_binary(id) and is_map(attrs) do
  case Repo.get(EnrollmentSchema, id) do
    nil ->
      {:error, :not_found}

    schema ->
      schema
      |> EnrollmentSchema.update_changeset(attrs)
      |> Repo.update()
      |> case do
        {:ok, updated} ->
          Logger.info("[Enrollment.Repository] Updated enrollment",
            enrollment_id: id,
            status: attrs[:status]
          )

          {:ok, EnrollmentMapper.to_domain(updated)}

        {:error, changeset} ->
          Logger.warning("[Enrollment.Repository] Validation error updating enrollment",
            enrollment_id: id,
            errors: inspect(changeset.errors)
          )

          {:error, changeset}
      end
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_repository_test.exs`
Expected: ALL PASS

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/enrollment/domain/ports/for_managing_enrollments.ex \
        lib/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_repository.ex \
        test/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_repository_test.exs
git commit -m "feat(enrollment): add update/2 to enrollment port and repository"
```

---

### Task 2: Add `enrollment_cancelled` Domain Event

**Files:**
- Modify: `lib/klass_hero/enrollment/domain/events/enrollment_events.ex:133`
- Test: `test/klass_hero/enrollment/domain/events/enrollment_events_test.exs`

- [ ] **Step 1: Write failing tests**

Add to `enrollment_events_test.exs`:

```elixir
describe "enrollment_cancelled/3" do
  test "creates event with correct type and aggregate" do
    enrollment_id = Ecto.UUID.generate()

    payload = %{
      enrollment_id: enrollment_id,
      program_id: Ecto.UUID.generate(),
      child_id: Ecto.UUID.generate(),
      parent_id: Ecto.UUID.generate(),
      admin_id: Ecto.UUID.generate(),
      reason: "Duplicate booking",
      cancelled_at: DateTime.utc_now()
    }

    event = EnrollmentEvents.enrollment_cancelled(enrollment_id, payload)

    assert %DomainEvent{} = event
    assert event.event_type == :enrollment_cancelled
    assert event.aggregate_id == enrollment_id
    assert event.aggregate_type == :enrollment
    assert event.payload.enrollment_id == enrollment_id
    assert event.payload.admin_id == payload.admin_id
    assert event.payload.reason == "Duplicate booking"
  end

  test "base_payload enrollment_id wins over caller-supplied enrollment_id" do
    real_id = Ecto.UUID.generate()
    conflicting_payload = %{enrollment_id: "should-be-overridden", extra: "data"}

    event = EnrollmentEvents.enrollment_cancelled(real_id, conflicting_payload)

    assert event.payload.enrollment_id == real_id
    assert event.payload.extra == "data"
  end

  test "raises for nil enrollment_id" do
    assert_raise ArgumentError,
                 ~r/requires a non-empty enrollment_id string/,
                 fn -> EnrollmentEvents.enrollment_cancelled(nil, %{}) end
  end

  test "raises for empty string enrollment_id" do
    assert_raise ArgumentError,
                 ~r/requires a non-empty enrollment_id string/,
                 fn -> EnrollmentEvents.enrollment_cancelled("", %{}) end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/enrollment/domain/events/enrollment_events_test.exs --max-failures 1`
Expected: FAIL — `enrollment_cancelled/3` is undefined

- [ ] **Step 3: Implement the event factory**

Add to `lib/klass_hero/enrollment/domain/events/enrollment_events.ex` before the final `end`:

```elixir
@doc """
Creates an `:enrollment_cancelled` event when an enrollment is cancelled.

## Parameters

- `enrollment_id` — the cancelled enrollment's ID
- `payload` — event data including program_id, child_id, parent_id, admin_id, reason, cancelled_at
- `opts` — forwarded to `DomainEvent.new/5` (e.g. `:correlation_id`)
"""
def enrollment_cancelled(enrollment_id, payload \\ %{}, opts \\ [])

def enrollment_cancelled(enrollment_id, payload, opts)
    when is_binary(enrollment_id) and byte_size(enrollment_id) > 0 do
  base_payload = %{enrollment_id: enrollment_id}

  DomainEvent.new(
    :enrollment_cancelled,
    enrollment_id,
    @aggregate_type,
    # Trigger: caller may pass a conflicting :enrollment_id in payload
    # Why: base_payload contains the canonical enrollment_id from the function argument
    # Outcome: base_payload keys always win, preventing accidental overwrite
    Map.merge(payload, base_payload),
    opts
  )
end

def enrollment_cancelled(enrollment_id, _payload, _opts) do
  raise ArgumentError,
        "enrollment_cancelled/3 requires a non-empty enrollment_id string, got: #{inspect(enrollment_id)}"
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/enrollment/domain/events/enrollment_events_test.exs`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/enrollment/domain/events/enrollment_events.ex \
        test/klass_hero/enrollment/domain/events/enrollment_events_test.exs
git commit -m "feat(enrollment): add enrollment_cancelled domain event factory"
```

---

### Task 3: Add `enrollment_cancelled` Integration Event

**Files:**
- Modify: `lib/klass_hero/enrollment/domain/events/enrollment_integration_events.ex:97`
- Test: `test/klass_hero/enrollment/domain/events/enrollment_integration_events_test.exs`

- [ ] **Step 1: Write failing tests**

Add to `enrollment_integration_events_test.exs`:

```elixir
describe "enrollment_cancelled/3" do
  test "creates integration event with correct structure" do
    enrollment_id = Ecto.UUID.generate()

    payload = %{
      enrollment_id: enrollment_id,
      program_id: Ecto.UUID.generate(),
      admin_id: Ecto.UUID.generate(),
      reason: "Admin cancellation"
    }

    event = EnrollmentIntegrationEvents.enrollment_cancelled(enrollment_id, payload)

    assert %IntegrationEvent{} = event
    assert event.event_type == :enrollment_cancelled
    assert event.source_context == :enrollment
    assert event.entity_type == :enrollment
    assert event.entity_id == enrollment_id
  end

  test "base_payload enrollment_id wins over caller-supplied enrollment_id" do
    real_id = Ecto.UUID.generate()
    conflicting_payload = %{enrollment_id: "should-be-overridden", extra: "data"}

    event = EnrollmentIntegrationEvents.enrollment_cancelled(real_id, conflicting_payload)

    assert event.payload.enrollment_id == real_id
    assert event.payload.extra == "data"
  end

  test "raises for nil enrollment_id" do
    assert_raise ArgumentError,
                 ~r/requires a non-empty enrollment_id string/,
                 fn -> EnrollmentIntegrationEvents.enrollment_cancelled(nil) end
  end

  test "raises for empty string enrollment_id" do
    assert_raise ArgumentError,
                 ~r/requires a non-empty enrollment_id string/,
                 fn -> EnrollmentIntegrationEvents.enrollment_cancelled("") end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/enrollment/domain/events/enrollment_integration_events_test.exs --max-failures 1`
Expected: FAIL — `enrollment_cancelled` is undefined

- [ ] **Step 3: Implement the integration event factory**

Add to `lib/klass_hero/enrollment/domain/events/enrollment_integration_events.ex` before the final `end`:

```elixir
@doc """
Creates an `:enrollment_cancelled` integration event.

## Parameters

- `enrollment_id` - the cancelled enrollment's ID
- `payload` - event data including admin_id, reason, etc.
- `opts` - metadata options (correlation_id, causation_id)

## Raises

- `ArgumentError` if `enrollment_id` is nil or empty
"""
def enrollment_cancelled(enrollment_id, payload \\ %{}, opts \\ [])

def enrollment_cancelled(enrollment_id, payload, opts)
    when is_binary(enrollment_id) and byte_size(enrollment_id) > 0 do
  base_payload = %{enrollment_id: enrollment_id}

  IntegrationEvent.new(
    :enrollment_cancelled,
    @source_context,
    # Trigger: enrollment_cancelled uses a different entity type than the module default
    # Why: @entity_type is :participant_policy for existing functions; enrollments
    #   are a separate entity type in the enrollment context
    # Outcome: hardcoded :enrollment ensures correct entity classification
    :enrollment,
    enrollment_id,
    Map.merge(payload, base_payload),
    opts
  )
end

def enrollment_cancelled(enrollment_id, _payload, _opts) do
  raise ArgumentError,
        "enrollment_cancelled/3 requires a non-empty enrollment_id string, got: #{inspect(enrollment_id)}"
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/enrollment/domain/events/enrollment_integration_events_test.exs`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/enrollment/domain/events/enrollment_integration_events.ex \
        test/klass_hero/enrollment/domain/events/enrollment_integration_events_test.exs
git commit -m "feat(enrollment): add enrollment_cancelled integration event factory"
```

---

### Task 4: Handle `enrollment_cancelled` in PromoteIntegrationEvents

**Files:**
- Modify: `lib/klass_hero/enrollment/adapters/driven/events/event_handlers/promote_integration_events.ex:34`
- Test: `test/klass_hero/enrollment/adapters/driven/events/event_handlers/promote_integration_events_test.exs`

- [ ] **Step 1: Write failing test**

Add to `promote_integration_events_test.exs`:

```elixir
describe "handle/1 — :enrollment_cancelled" do
  test "promotes to enrollment_cancelled integration event" do
    enrollment_id = Ecto.UUID.generate()
    admin_id = Ecto.UUID.generate()

    domain_event =
      DomainEvent.new(:enrollment_cancelled, enrollment_id, :enrollment, %{
        enrollment_id: enrollment_id,
        admin_id: admin_id,
        reason: "Duplicate booking"
      })

    assert :ok = PromoteIntegrationEvents.handle(domain_event)

    event = assert_integration_event_published(:enrollment_cancelled)
    assert event.entity_id == enrollment_id
    assert event.source_context == :enrollment
    assert event.entity_type == :enrollment
    assert event.payload.enrollment_id == enrollment_id
    assert event.payload.admin_id == admin_id
  end

  test "propagates publish failures as {:error, reason}" do
    enrollment_id = Ecto.UUID.generate()

    domain_event =
      DomainEvent.new(:enrollment_cancelled, enrollment_id, :enrollment, %{
        enrollment_id: enrollment_id
      })

    TestIntegrationEventPublisher.configure_publish_error(:pubsub_down)

    assert {:error, :pubsub_down} = PromoteIntegrationEvents.handle(domain_event)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/enrollment/adapters/driven/events/event_handlers/promote_integration_events_test.exs --max-failures 1`
Expected: FAIL — no matching function clause for `:enrollment_cancelled`

- [ ] **Step 3: Add handler clause**

Add to `promote_integration_events.ex` before the final `end`:

```elixir
def handle(%DomainEvent{event_type: :enrollment_cancelled} = event) do
  # Trigger: enrollment_cancelled domain event dispatched from CancelEnrollmentByAdmin use case
  # Why: downstream contexts may react to cancellations (e.g., notifications, analytics)
  # Outcome: publish integration event on topic integration:enrollment:enrollment_cancelled
  event.payload.enrollment_id
  |> EnrollmentIntegrationEvents.enrollment_cancelled(event.payload)
  |> IntegrationEventPublishing.publish_critical("enrollment_cancelled",
    enrollment_id: event.payload.enrollment_id
  )
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/enrollment/adapters/driven/events/event_handlers/promote_integration_events_test.exs`
Expected: ALL PASS

- [ ] **Step 5: Register handler in application.ex**

In `lib/klass_hero/application.ex`, inside the `:enrollment_domain_event_bus` handler list (after the `:invite_claimed` PromoteIntegrationEvents entry, around line 137), add:

```elixir
{:enrollment_cancelled,
 {KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
  :handle}, priority: 10}
```

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/enrollment/adapters/driven/events/event_handlers/promote_integration_events.ex \
        test/klass_hero/enrollment/adapters/driven/events/event_handlers/promote_integration_events_test.exs \
        lib/klass_hero/application.ex
git commit -m "feat(enrollment): promote enrollment_cancelled to integration event"
```

---

### Task 5: CancelEnrollmentByAdmin Use Case

**Files:**
- Create: `lib/klass_hero/enrollment/application/use_cases/cancel_enrollment_by_admin.ex`
- Create: `test/klass_hero/enrollment/application/use_cases/cancel_enrollment_by_admin_test.exs`
- Modify: `lib/klass_hero/enrollment.ex:67` (add alias + facade)

- [ ] **Step 1: Write failing tests**

Create `test/klass_hero/enrollment/application/use_cases/cancel_enrollment_by_admin_test.exs`:

Note: Event dispatch is NOT tested here — `DomainEventBus.dispatch` routes through registered handlers, not `TestEventPublisher`. Event promotion is tested in the `PromoteIntegrationEvents` handler test (Task 4). This follows the `SetParticipantPolicy` test pattern.

```elixir
defmodule KlassHero.Enrollment.Application.UseCases.CancelEnrollmentByAdminTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Application.UseCases.CancelEnrollmentByAdmin
  alias KlassHero.Enrollment.Domain.Models.Enrollment

  describe "execute/3" do
    test "cancels a pending enrollment and returns domain entity" do
      schema = insert(:enrollment_schema, status: "pending")
      admin_id = Ecto.UUID.generate()

      assert {:ok, enrollment} = CancelEnrollmentByAdmin.execute(schema.id, admin_id, "Duplicate booking")
      assert %Enrollment{} = enrollment
      assert enrollment.status == :cancelled
      assert enrollment.cancellation_reason == "Duplicate booking"
      assert enrollment.cancelled_at != nil
    end

    test "cancels a confirmed enrollment" do
      schema = insert(:enrollment_schema, status: "confirmed")
      admin_id = Ecto.UUID.generate()

      assert {:ok, enrollment} = CancelEnrollmentByAdmin.execute(schema.id, admin_id, "Parent requested")
      assert enrollment.status == :cancelled
    end

    test "returns invalid_status_transition for completed enrollment" do
      schema = insert(:enrollment_schema, status: "completed")
      admin_id = Ecto.UUID.generate()

      assert {:error, :invalid_status_transition} =
               CancelEnrollmentByAdmin.execute(schema.id, admin_id, "Too late")
    end

    test "returns invalid_status_transition for already cancelled enrollment" do
      schema = insert(:enrollment_schema, status: "cancelled")
      admin_id = Ecto.UUID.generate()

      assert {:error, :invalid_status_transition} =
               CancelEnrollmentByAdmin.execute(schema.id, admin_id, "Already gone")
    end

    test "returns not_found for nonexistent enrollment" do
      admin_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               CancelEnrollmentByAdmin.execute(Ecto.UUID.generate(), admin_id, "Nope")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/enrollment/application/use_cases/cancel_enrollment_by_admin_test.exs --max-failures 1`
Expected: FAIL — module `CancelEnrollmentByAdmin` is not available

- [ ] **Step 3: Implement the use case**

Create `lib/klass_hero/enrollment/application/use_cases/cancel_enrollment_by_admin.ex`:

```elixir
defmodule KlassHero.Enrollment.Application.UseCases.CancelEnrollmentByAdmin do
  @moduledoc """
  Cancels an enrollment by admin action.

  Loads the enrollment, applies the domain cancellation (with lifecycle guards),
  persists the change, and dispatches an enrollment_cancelled domain event.
  """

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.EnrollmentMapper
  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Enrollment.Domain.Models.Enrollment
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @context KlassHero.Enrollment

  @enrollment_repo Application.compile_env!(
                     :klass_hero,
                     [:enrollment, :for_managing_enrollments]
                   )

  @doc """
  Cancels an enrollment identified by `enrollment_id`.

  ## Parameters

  - `enrollment_id` — UUID of the enrollment to cancel
  - `admin_id` — UUID of the admin performing the cancellation
  - `reason` — human-readable cancellation reason (required)

  ## Returns

  - `{:ok, Enrollment.t()}` — cancellation succeeded
  - `{:error, :not_found}` — enrollment does not exist
  - `{:error, :invalid_status_transition}` — enrollment is completed or already cancelled
  """
  @spec execute(String.t(), String.t(), String.t()) ::
          {:ok, Enrollment.t()} | {:error, :not_found | :invalid_status_transition | term()}
  def execute(enrollment_id, admin_id, reason)
      when is_binary(enrollment_id) and is_binary(admin_id) and is_binary(reason) do
    with {:ok, enrollment} <- @enrollment_repo.get_by_id(enrollment_id),
         {:ok, cancelled} <- Enrollment.cancel(enrollment, reason),
         attrs <- EnrollmentMapper.to_schema(cancelled),
         {:ok, persisted} <- @enrollment_repo.update(enrollment_id, attrs) do
      dispatch_event(persisted, admin_id, reason)

      Logger.info("[Enrollment.CancelByAdmin] Enrollment cancelled by admin",
        enrollment_id: enrollment_id,
        admin_id: admin_id
      )

      {:ok, persisted}
    end
  end

  defp dispatch_event(enrollment, admin_id, reason) do
    EnrollmentEvents.enrollment_cancelled(enrollment.id, %{
      enrollment_id: enrollment.id,
      program_id: enrollment.program_id,
      child_id: enrollment.child_id,
      parent_id: enrollment.parent_id,
      admin_id: admin_id,
      reason: reason,
      cancelled_at: enrollment.cancelled_at
    })
    |> then(&DomainEventBus.dispatch(@context, &1))
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/enrollment/application/use_cases/cancel_enrollment_by_admin_test.exs`
Expected: ALL PASS

- [ ] **Step 5: Add facade function**

Add alias to `lib/klass_hero/enrollment.ex` after line 66 (the `SetParticipantPolicy` alias):

```elixir
alias KlassHero.Enrollment.Application.UseCases.CancelEnrollmentByAdmin
```

Add function to the Enrollment Management Functions section (after `get_enrollment/1`):

```elixir
@doc """
Cancels an enrollment by admin action.

Enforces domain lifecycle guards (only pending/confirmed can be cancelled),
persists the status change, and dispatches an enrollment_cancelled domain event.

## Parameters

- `enrollment_id` — UUID of the enrollment
- `admin_id` — UUID of the admin performing the cancellation
- `reason` — human-readable cancellation reason

## Returns

- `{:ok, Enrollment.t()}` — cancellation succeeded
- `{:error, :not_found}` — enrollment does not exist
- `{:error, :invalid_status_transition}` — enrollment is completed or already cancelled
"""
def cancel_enrollment_by_admin(enrollment_id, admin_id, reason)
    when is_binary(enrollment_id) and is_binary(admin_id) and is_binary(reason) do
  CancelEnrollmentByAdmin.execute(enrollment_id, admin_id, reason)
end
```

- [ ] **Step 6: Run all enrollment tests**

Run: `mix test test/klass_hero/enrollment/`
Expected: ALL PASS

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero/enrollment/application/use_cases/cancel_enrollment_by_admin.ex \
        test/klass_hero/enrollment/application/use_cases/cancel_enrollment_by_admin_test.exs \
        lib/klass_hero/enrollment.ex
git commit -m "feat(enrollment): add CancelEnrollmentByAdmin use case with event dispatch"
```

---

## Chunk 2: Web Layer (Backpex Resource + Action)

### Task 6: Add `belongs_to` Associations and `admin_changeset` to EnrollmentSchema

**Files:**
- Modify: `lib/klass_hero/enrollment/adapters/driven/persistence/schemas/enrollment_schema.ex`

- [ ] **Step 1: Replace bare UUID fields with `belongs_to` associations**

In `enrollment_schema.ex`, replace lines 21-23:

```elixir
field :program_id, :binary_id
field :child_id, :binary_id
field :parent_id, :binary_id
```

With:

```elixir
belongs_to :program, KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
belongs_to :child, KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildSchema
belongs_to :parent, KlassHero.Family.Adapters.Driven.Persistence.Schemas.ParentProfileSchema,
  foreign_key: :parent_id,
  references: :id
```

- [ ] **Step 2: Add `admin_changeset/3`**

Add after the `update_changeset/2` function:

```elixir
@doc """
No-op changeset required by Backpex even when edit is disabled via `can?/3`.
"""
def admin_changeset(schema, _attrs, _metadata), do: change(schema)
```

- [ ] **Step 3: Run existing enrollment tests to verify nothing broke**

Run: `mix test test/klass_hero/enrollment/`
Expected: ALL PASS — `belongs_to` defines the same FK fields implicitly

- [ ] **Step 4: Commit**

```bash
git add lib/klass_hero/enrollment/adapters/driven/persistence/schemas/enrollment_schema.ex
git commit -m "feat(enrollment): add belongs_to associations and admin_changeset to EnrollmentSchema"
```

---

### Task 7: Create StatusFilter

**Files:**
- Create: `lib/klass_hero_web/live/admin/filters/status_filter.ex`

- [ ] **Step 1: Create the filter module**

Follows the exact pattern of `ActiveFilter` and `VerifiedFilter`.

Create `lib/klass_hero_web/live/admin/filters/status_filter.ex`:

```elixir
defmodule KlassHeroWeb.Admin.Filters.StatusFilter do
  @moduledoc false

  use Backpex.Filters.Boolean

  import Ecto.Query

  @impl Backpex.Filter
  def label, do: "Booking Status"

  @impl Backpex.Filters.Boolean
  def options(_assigns) do
    [
      %{label: "Pending", key: "pending", predicate: dynamic([x], x.status == "pending")},
      %{label: "Confirmed", key: "confirmed", predicate: dynamic([x], x.status == "confirmed")},
      %{label: "Completed", key: "completed", predicate: dynamic([x], x.status == "completed")},
      %{label: "Cancelled", key: "cancelled", predicate: dynamic([x], x.status == "cancelled")}
    ]
  end
end
```

- [ ] **Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: compiles without warnings

- [ ] **Step 3: Commit**

```bash
git add lib/klass_hero_web/live/admin/filters/status_filter.ex
git commit -m "feat(admin): add StatusFilter for enrollment status filtering"
```

---

### Task 8: Create CancelBookingAction

**Files:**
- Create: `lib/klass_hero_web/live/admin/actions/cancel_booking_action.ex`

- [ ] **Step 1: Create the item action module**

Create `lib/klass_hero_web/live/admin/actions/cancel_booking_action.ex`:

```elixir
defmodule KlassHeroWeb.Admin.Actions.CancelBookingAction do
  @moduledoc """
  Backpex item action for cancelling bookings from the admin dashboard.

  Shows a confirmation modal with consequence warning and requires a
  cancellation reason. Delegates to the CancelEnrollmentByAdmin use case
  which enforces domain lifecycle guards and dispatches events.
  """

  use BackpexWeb, :item_action

  import Ecto.Changeset

  @impl Backpex.ItemAction
  def icon(assigns, _item) do
    ~H"""
    <Backpex.HTML.CoreComponents.icon name="hero-x-circle" class="h-5 w-5 text-red-600" />
    """
  end

  @impl Backpex.ItemAction
  def label(_assigns, _item), do: "Cancel Booking"

  @impl Backpex.ItemAction
  def confirm(_assigns) do
    "This will free the reserved slot and cannot be undone. Are you sure?"
  end

  @impl Backpex.ItemAction
  def confirm_label(_assigns), do: "Cancel Booking"

  @impl Backpex.ItemAction
  def fields do
    [
      reason: %{
        module: Backpex.Fields.Textarea,
        label: "Cancellation Reason",
        type: :string
      }
    ]
  end

  @impl Backpex.ItemAction
  def changeset(change, attrs, _metadata) do
    change
    |> cast(attrs, [:reason])
    |> validate_required([:reason])
    |> validate_length(:reason, min: 1, max: 1000)
  end

  @impl Backpex.ItemAction
  def handle(socket, items, data) do
    admin_id = socket.assigns.current_scope.user.id

    results =
      Enum.map(items, fn item ->
        KlassHero.Enrollment.cancel_enrollment_by_admin(item.id, admin_id, data.reason)
      end)

    # Trigger: check if any cancellation failed
    # Why: some items may be in a non-cancellable state (completed/cancelled)
    # Outcome: flash appropriate success or error message
    errors = Enum.filter(results, &match?({:error, _}, &1))

    socket =
      if errors == [] do
        Phoenix.LiveView.put_flash(socket, :info, "Booking(s) cancelled successfully.")
      else
        Phoenix.LiveView.put_flash(
          socket,
          :error,
          "Some bookings could not be cancelled (already completed or cancelled)."
        )
      end

    {:ok, socket}
  end
end
```

- [ ] **Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: compiles without warnings

- [ ] **Step 3: Commit**

```bash
git add lib/klass_hero_web/live/admin/actions/cancel_booking_action.ex
git commit -m "feat(admin): add CancelBookingAction item action with reason modal"
```

---

### Task 9: Create BookingLive Backpex Resource

**Files:**
- Create: `lib/klass_hero_web/live/admin/booking_live.ex`
- Modify: `lib/klass_hero_web/router.ex:151`

- [ ] **Step 1: Create the Backpex resource**

Create `lib/klass_hero_web/live/admin/booking_live.ex`:

```elixir
defmodule KlassHeroWeb.Admin.BookingLive do
  @moduledoc """
  Backpex LiveResource for viewing bookings in the admin dashboard.

  Provides index and show views. Enrollments are read-only — the only
  mutation is the cancel item action which goes through the
  CancelEnrollmentByAdmin use case.

  Note: Backpex operates directly on Ecto schemas and Repo, bypassing
  the Ports & Adapters layering used elsewhere. This is a pragmatic
  exception scoped to admin-only read operations.
  """

  # Backpex requires FQ refs in `use` args — alias can't precede `use` per formatter rules
  # credo:disable-for-lines:10 Credo.Check.Design.AliasUsage
  use Backpex.LiveResource,
    adapter_config: [
      schema: KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentSchema,
      repo: KlassHero.Repo,
      update_changeset:
        &KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentSchema.admin_changeset/3,
      create_changeset:
        &KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentSchema.admin_changeset/3
    ],
    layout: {KlassHeroWeb.Layouts, :admin},
    pubsub: [server: KlassHero.PubSub],
    init_order: %{by: :enrolled_at, direction: :desc}

  # Trigger: :new, :edit, and :delete are not valid operations for bookings in admin
  # Why: bookings are created by parents; cancellation goes through the cancel item action
  # Outcome: hides "New" button, denies edit/delete actions
  @impl Backpex.LiveResource
  def can?(_assigns, :new, _item), do: false
  def can?(_assigns, :edit, _item), do: false
  def can?(_assigns, :delete, _item), do: false
  def can?(_assigns, :index, _item), do: true
  def can?(_assigns, :show, _item), do: true

  # Trigger: cancel action should only be available for cancellable statuses
  # Why: completed and cancelled enrollments cannot be cancelled again
  # Outcome: cancel button only appears for pending/confirmed enrollments
  def can?(_assigns, :cancel_booking, item) do
    item.status in ~w(pending confirmed)
  end

  def can?(_assigns, _action, _item), do: false

  @impl Backpex.LiveResource
  def filters do
    [status: %{module: KlassHeroWeb.Admin.Filters.StatusFilter}]
  end

  @impl Backpex.LiveResource
  def singular_name, do: "Booking"

  @impl Backpex.LiveResource
  def plural_name, do: "Bookings"

  @impl Backpex.LiveResource
  def item_actions(default_actions) do
    # Trigger: override default actions to add custom cancel action
    # Why: the cancel action calls through a domain use case, not a simple Backpex edit
    # Outcome: cancel button appears per-row for eligible bookings
    Keyword.merge(default_actions,
      cancel_booking: %{
        module: KlassHeroWeb.Admin.Actions.CancelBookingAction,
        only: [:row, :show]
      }
    )
  end

  @impl Backpex.LiveResource
  def fields do
    [
      program: %{
        module: Backpex.Fields.BelongsTo,
        label: "Program",
        display_field: :title,
        searchable: true,
        orderable: true,
        only: [:index, :show]
      },
      child: %{
        module: Backpex.Fields.BelongsTo,
        label: "Child",
        display_field: :first_name,
        searchable: true,
        only: [:index, :show],
        render: fn assigns ->
          ~H"""
          <%= if @value do %>
            {@value.first_name} {@value.last_name}
          <% else %>
            <span class="text-gray-400 italic">Deleted</span>
          <% end %>
          """
        end
      },
      parent: %{
        module: Backpex.Fields.BelongsTo,
        label: "Parent",
        display_field: :display_name,
        searchable: true,
        only: [:index, :show]
      },
      status: %{
        module: Backpex.Fields.Text,
        label: "Status",
        orderable: true,
        render: fn assigns ->
          ~H"""
          <span class={[
            "inline-flex items-center rounded-full px-2 py-1 text-xs font-medium",
            status_badge_class(@value)
          ]}>
            {String.capitalize(@value || "")}
          </span>
          """
        end
      },
      total_amount: %{
        module: Backpex.Fields.Text,
        label: "Total",
        orderable: true,
        render: fn assigns ->
          ~H"""
          <%= if @value do %>
            &euro;{Decimal.round(@value, 2)}
          <% else %>
            &mdash;
          <% end %>
          """
        end
      },
      payment_method: %{
        module: Backpex.Fields.Text,
        label: "Payment",
        only: [:show],
        render: fn assigns ->
          ~H"""
          {String.capitalize(@value || "—")}
          """
        end
      },
      enrolled_at: %{
        module: Backpex.Fields.DateTime,
        label: "Enrolled At",
        orderable: true
      },
      special_requirements: %{
        module: Backpex.Fields.Textarea,
        label: "Special Requirements",
        only: [:show]
      },
      cancellation_reason: %{
        module: Backpex.Fields.Text,
        label: "Cancellation Reason",
        only: [:show]
      },
      confirmed_at: %{
        module: Backpex.Fields.DateTime,
        label: "Confirmed At",
        only: [:show]
      },
      cancelled_at: %{
        module: Backpex.Fields.DateTime,
        label: "Cancelled At",
        only: [:show]
      }
    ]
  end

  defp status_badge_class("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_badge_class("confirmed"), do: "bg-green-100 text-green-800"
  defp status_badge_class("completed"), do: "bg-blue-100 text-blue-800"
  defp status_badge_class("cancelled"), do: "bg-red-100 text-red-800"
  defp status_badge_class(_), do: "bg-gray-100 text-gray-800"
end
```

- [ ] **Step 2: Add route to router**

In `lib/klass_hero_web/router.ex`, add after line 151 (`live_resources("/staff", ...)`):

```elixir
live_resources("/bookings", BookingLive, only: [:index, :show])
```

- [ ] **Step 3: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: compiles without warnings

- [ ] **Step 4: Commit**

```bash
git add lib/klass_hero_web/live/admin/booking_live.ex lib/klass_hero_web/router.ex
git commit -m "feat(admin): add BookingLive Backpex resource with cancel action and status filter"
```

---

### Task 10: BookingLive Tests

**Files:**
- Create: `test/klass_hero_web/live/admin/booking_live_test.exs`

- [ ] **Step 1: Write LiveView tests**

Follows the pattern established in `staff_live_test.exs`.

Create `test/klass_hero_web/live/admin/booking_live_test.exs`:

```elixir
defmodule KlassHeroWeb.Admin.BookingLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import Phoenix.LiveViewTest

  describe "admin access control" do
    setup :register_and_log_in_admin

    test "admin can access /admin/bookings", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/bookings")
      assert html =~ "Bookings"
    end

    test "new booking button is not shown on index", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/bookings")
      refute has_element?(view, "a", "New")
    end
  end

  describe "non-admin access control" do
    setup :register_and_log_in_user

    test "non-admin is redirected from /admin/bookings", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/", flash: flash}}} = live(conn, ~p"/admin/bookings")
      assert flash["error"] =~ "access"
    end
  end

  describe "unauthenticated access control" do
    test "unauthenticated user is redirected from /admin/bookings", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin/bookings")
    end
  end

  describe "booking list" do
    setup :register_and_log_in_admin

    test "displays bookings in the table", %{conn: conn} do
      enrollment = insert(:enrollment_schema, status: "pending")
      program = KlassHero.Repo.get!(KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema, enrollment.program_id)

      {:ok, view, _html} = live(conn, ~p"/admin/bookings")

      assert has_element?(view, "td", program.title)
      assert has_element?(view, "td", "Pending")
    end
  end

  describe "booking show" do
    setup :register_and_log_in_admin

    test "displays booking detail", %{conn: conn} do
      enrollment = insert(:enrollment_schema, status: "confirmed", special_requirements: "Allergic to nuts")

      {:ok, _view, html} = live(conn, ~p"/admin/bookings/#{enrollment.id}")

      assert html =~ "Confirmed"
      assert html =~ "Allergic to nuts"
    end
  end
end
```

- [ ] **Step 2: Run tests**

Run: `mix test test/klass_hero_web/live/admin/booking_live_test.exs`
Expected: ALL PASS

- [ ] **Step 3: Commit**

```bash
git add test/klass_hero_web/live/admin/booking_live_test.exs
git commit -m "test(admin): add BookingLive access control and listing tests"
```

---

### Task 11: Final Validation

- [ ] **Step 1: Run full precommit**

Run: `mix precommit`
Expected: compile (0 warnings), format (clean), test (ALL PASS)

- [ ] **Step 2: Fix any warnings or failures**

If any warnings from new code, fix them. If any tests fail, debug and fix.

- [ ] **Step 3: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: resolve precommit warnings and test failures"
```
