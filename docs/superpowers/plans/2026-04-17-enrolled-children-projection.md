# Enrolled Children Projection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **REQUIRED SKILLS:** Use `superpowers:test-driven-development` for all implementation. Use `idiomatic-elixir` when writing `.ex`/`.exs` files. Use `phoenix-pubsub` for event publishing/subscription patterns.
>
> **TIDEWAVE MCP PRIORITY:** ALWAYS prefer Tidewave MCP tools over bash for Elixir evaluation (`project_eval`), documentation lookup (`get_docs`), SQL queries (`execute_sql_query`), schema inspection (`get_ecto_schemas`), and log checking (`get_logs`). Alert immediately if Tidewave is unavailable.

**Goal:** Show parent name and enrolled child names in conversation headers by building an event-driven projection that resolves enrollment data within the Messaging context.

**Architecture:** Create missing integration events in Enrollment and Family contexts. Build an `EnrolledChildren` projection GenServer within Messaging that subscribes to cross-context events, maintains a local lookup table, and emits internal `enrolled_children_changed` domain events. Extend the existing `ConversationSummaries` projection to react to that internal event. Update the web layer to display the resolved names.

**Tech Stack:** Elixir 1.20, Phoenix 1.8, Phoenix PubSub, Ecto, PostgreSQL, GenServer, Gettext

**Spec:** `docs/superpowers/specs/2026-04-17-enrolled-children-projection-design.md`

---

## File Map

### New files

| File | Responsibility |
|---|---|
| `priv/repo/migrations/TIMESTAMP_create_messaging_enrolled_children.exs` | Migration: `messaging_enrolled_children` table |
| `priv/repo/migrations/TIMESTAMP_add_enrolled_child_names_to_conversation_summaries.exs` | Migration: add `enrolled_child_names` column |
| `lib/klass_hero/messaging/adapters/driven/persistence/schemas/enrolled_children_schema.ex` | Ecto schema for `messaging_enrolled_children` |
| `lib/klass_hero/messaging/adapters/driven/projections/enrolled_children.ex` | GenServer projection for enrolled children lookup |
| `test/klass_hero/enrollment/domain/events/enrollment_events_enrollment_created_test.exs` | Tests for `enrollment_created` domain event |
| `test/klass_hero/enrollment/domain/events/enrollment_integration_events_enrollment_created_test.exs` | Tests for `enrollment_created` integration event |
| `test/klass_hero/family/domain/events/family_events_child_lifecycle_test.exs` | Tests for `child_created`/`child_updated` domain events |
| `test/klass_hero/family/domain/events/family_integration_events_child_lifecycle_test.exs` | Tests for `child_created`/`child_updated` integration events |
| `test/klass_hero/messaging/adapters/driven/projections/enrolled_children_test.exs` | Tests for EnrolledChildren projection |

### Modified files

| File | Change |
|---|---|
| `lib/klass_hero/enrollment/domain/events/enrollment_events.ex` | Add `enrollment_created/3` |
| `lib/klass_hero/enrollment/domain/events/enrollment_integration_events.ex` | Add `enrollment_created/3` |
| `lib/klass_hero/enrollment/adapters/driving/events/event_handlers/promote_integration_events.ex` | Add `:enrollment_created` clause |
| `lib/klass_hero/enrollment/application/commands/create_enrollment.ex` | Dispatch `enrollment_created` domain event |
| `lib/klass_hero/messaging/application/queries/list_conversations.ex` | Add `enrolled_child_names` to `to_enriched_map/1` |
| `lib/klass_hero/family/domain/events/family_events.ex` | Add `child_created/3`, `child_updated/3` |
| `lib/klass_hero/family/domain/events/family_integration_events.ex` | Add `child_created/3`, `child_updated/3` |
| `lib/klass_hero/family/adapters/driving/events/event_handlers/promote_integration_events.ex` | Add `:child_created`, `:child_updated` clauses |
| `lib/klass_hero/family/application/commands/children/create_child.ex` | Dispatch `child_created` domain event |
| `lib/klass_hero/family/application/commands/children/update_child.ex` | Dispatch `child_updated` domain event |
| `lib/klass_hero/messaging/domain/events/messaging_events.ex` | Add `program_id` param to `conversation_created` |
| `lib/klass_hero/messaging/application/commands/create_direct_conversation.ex` | Pass `program_id` to event |
| `lib/klass_hero/messaging/adapters/driven/persistence/schemas/conversation_summary_schema.ex` | Add `enrolled_child_names` field |
| `lib/klass_hero/messaging/domain/read_models/conversation_summary.ex` | Add `enrolled_child_names` field |
| `lib/klass_hero/messaging/adapters/driven/persistence/repositories/conversation_summaries_repository.ex` | Map `enrolled_child_names` in `to_dto/1` |
| `lib/klass_hero/messaging/adapters/driven/projections/conversation_summaries.ex` | Subscribe to new topic, handle `enrolled_children_changed`, update bootstrap |
| `lib/klass_hero/projection_supervisor.ex` | Add `EnrolledChildren` before `ConversationSummaries` |
| `lib/klass_hero/application.ex` | Register new event bus handlers and event subscribers |
| `lib/klass_hero_web/live/messaging_live_helper.ex` | Change `get_conversation_title` to arity 3, add `fetch_enrolled_child_names/2` |
| `lib/klass_hero_web/components/messaging_components.ex` | Add child names subtitle to provider conversation card |
| `test/klass_hero_web/live/messaging_live_helper_test.exs` | Update tests for `get_conversation_title/3` |

---

### Task 1: `enrollment_created` Domain + Integration Events

**Files:**
- Create: `test/klass_hero/enrollment/domain/events/enrollment_events_enrollment_created_test.exs`
- Create: `test/klass_hero/enrollment/domain/events/enrollment_integration_events_enrollment_created_test.exs`
- Modify: `lib/klass_hero/enrollment/domain/events/enrollment_events.ex`
- Modify: `lib/klass_hero/enrollment/domain/events/enrollment_integration_events.ex`

- [ ] **Step 1: Write failing test for `enrollment_created` domain event**

```elixir
# test/klass_hero/enrollment/domain/events/enrollment_events_enrollment_created_test.exs
defmodule KlassHero.Enrollment.Domain.Events.EnrollmentEventsEnrollmentCreatedTest do
  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent

  describe "enrollment_created/3" do
    test "creates event with correct type and aggregate" do
      enrollment_id = Ecto.UUID.generate()

      payload = %{
        enrollment_id: enrollment_id,
        child_id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate(),
        parent_user_id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        status: "pending"
      }

      event = EnrollmentEvents.enrollment_created(enrollment_id, payload)

      assert %DomainEvent{} = event
      assert event.event_type == :enrollment_created
      assert event.aggregate_id == enrollment_id
      assert event.aggregate_type == :enrollment
      assert event.payload.enrollment_id == enrollment_id
      assert event.payload.child_id == payload.child_id
      assert event.payload.parent_user_id == payload.parent_user_id
      assert event.payload.program_id == payload.program_id
    end

    test "base_payload enrollment_id wins over caller-supplied enrollment_id" do
      real_id = Ecto.UUID.generate()
      conflicting_payload = %{enrollment_id: "should-be-overridden", extra: "data"}

      event = EnrollmentEvents.enrollment_created(real_id, conflicting_payload)

      assert event.payload.enrollment_id == real_id
      assert event.payload.extra == "data"
    end

    test "raises for nil enrollment_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty enrollment_id string/,
                   fn -> EnrollmentEvents.enrollment_created(nil) end
    end

    test "raises for empty string enrollment_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty enrollment_id string/,
                   fn -> EnrollmentEvents.enrollment_created("") end
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/enrollment/domain/events/enrollment_events_enrollment_created_test.exs --max-failures 1`
Expected: FAIL — `EnrollmentEvents.enrollment_created/2` is undefined

- [ ] **Step 3: Implement `enrollment_created` domain event factory**

Add to `lib/klass_hero/enrollment/domain/events/enrollment_events.ex`, after the `enrollment_cancelled` function (before the final `end`):

```elixir
  @doc """
  Creates an `:enrollment_created` event when a new enrollment is persisted.

  ## Parameters

  - `enrollment_id` — the new enrollment's ID
  - `payload` — event data including child_id, parent_id, parent_user_id, program_id, status
  - `opts` — forwarded to `DomainEvent.new/5` (e.g. `:correlation_id`)
  """
  def enrollment_created(enrollment_id, payload \\ %{}, opts \\ [])

  def enrollment_created(enrollment_id, payload, opts)
      when is_binary(enrollment_id) and byte_size(enrollment_id) > 0 do
    base_payload = %{enrollment_id: enrollment_id}

    DomainEvent.new(
      :enrollment_created,
      enrollment_id,
      @aggregate_type,
      Map.merge(payload, base_payload),
      opts
    )
  end

  def enrollment_created(enrollment_id, _payload, _opts) do
    raise ArgumentError,
          "enrollment_created/3 requires a non-empty enrollment_id string, got: #{inspect(enrollment_id)}"
  end
```

Also update the `@moduledoc` events list to include:
```
  - `:enrollment_created` - Emitted when a new enrollment is successfully created.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/enrollment/domain/events/enrollment_events_enrollment_created_test.exs`
Expected: 4 tests, 0 failures

- [ ] **Step 5: Write failing test for `enrollment_created` integration event**

```elixir
# test/klass_hero/enrollment/domain/events/enrollment_integration_events_enrollment_created_test.exs
defmodule KlassHero.Enrollment.Domain.Events.EnrollmentIntegrationEventsEnrollmentCreatedTest do
  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Domain.Events.EnrollmentIntegrationEvents
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  describe "enrollment_created/3" do
    test "creates integration event with correct structure" do
      enrollment_id = Ecto.UUID.generate()

      payload = %{
        enrollment_id: enrollment_id,
        child_id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate(),
        parent_user_id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        status: "pending"
      }

      event = EnrollmentIntegrationEvents.enrollment_created(enrollment_id, payload)

      assert %IntegrationEvent{} = event
      assert event.event_type == :enrollment_created
      assert event.source_context == :enrollment
      assert event.entity_type == :enrollment
      assert event.entity_id == enrollment_id
      assert event.payload.parent_user_id == payload.parent_user_id
    end

    test "base_payload enrollment_id wins over caller-supplied enrollment_id" do
      real_id = Ecto.UUID.generate()
      conflicting_payload = %{enrollment_id: "should-be-overridden", extra: "data"}

      event = EnrollmentIntegrationEvents.enrollment_created(real_id, conflicting_payload)

      assert event.payload.enrollment_id == real_id
      assert event.payload.extra == "data"
    end

    test "raises for nil enrollment_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty enrollment_id string/,
                   fn -> EnrollmentIntegrationEvents.enrollment_created(nil) end
    end

    test "raises for empty string enrollment_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty enrollment_id string/,
                   fn -> EnrollmentIntegrationEvents.enrollment_created("") end
    end
  end
end
```

- [ ] **Step 6: Run test to verify it fails**

Run: `mix test test/klass_hero/enrollment/domain/events/enrollment_integration_events_enrollment_created_test.exs --max-failures 1`
Expected: FAIL — `enrollment_created/2` is undefined

- [ ] **Step 7: Implement `enrollment_created` integration event factory**

Add to `lib/klass_hero/enrollment/domain/events/enrollment_integration_events.ex`, after the `enrollment_cancelled` function:

```elixir
  @typedoc "Payload for `:enrollment_created` events."
  @type enrollment_created_payload :: %{
          required(:enrollment_id) => String.t(),
          optional(atom()) => term()
        }

  @doc """
  Creates an `:enrollment_created` integration event.

  ## Parameters

  - `enrollment_id` - the new enrollment's ID
  - `payload` - event data including child_id, parent_id, parent_user_id, program_id, status
  - `opts` - metadata options (correlation_id, causation_id)

  ## Raises

  - `ArgumentError` if `enrollment_id` is nil or empty
  """
  def enrollment_created(enrollment_id, payload \\ %{}, opts \\ [])

  def enrollment_created(enrollment_id, payload, opts)
      when is_binary(enrollment_id) and byte_size(enrollment_id) > 0 do
    base_payload = %{enrollment_id: enrollment_id}

    IntegrationEvent.new(
      :enrollment_created,
      @source_context,
      :enrollment,
      enrollment_id,
      Map.merge(payload, base_payload),
      opts
    )
  end

  def enrollment_created(enrollment_id, _payload, _opts) do
    raise ArgumentError,
          "enrollment_created/3 requires a non-empty enrollment_id string, got: #{inspect(enrollment_id)}"
  end
```

Also update the `@moduledoc` events list to include:
```
  - `:enrollment_created` - Emitted when a new enrollment is successfully created.
    Downstream contexts can react to update projections or trigger workflows.
```

- [ ] **Step 8: Run test to verify it passes**

Run: `mix test test/klass_hero/enrollment/domain/events/enrollment_integration_events_enrollment_created_test.exs`
Expected: 4 tests, 0 failures

- [ ] **Step 9: Commit**

```bash
git add test/klass_hero/enrollment/domain/events/enrollment_events_enrollment_created_test.exs \
        test/klass_hero/enrollment/domain/events/enrollment_integration_events_enrollment_created_test.exs \
        lib/klass_hero/enrollment/domain/events/enrollment_events.ex \
        lib/klass_hero/enrollment/domain/events/enrollment_integration_events.ex
git commit -m "feat: add enrollment_created domain and integration events"
```

---

### Task 2: Wire `enrollment_created` — Promotion, Dispatch, and `enrollment_cancelled` Fix

**Files:**
- Modify: `lib/klass_hero/enrollment/adapters/driving/events/event_handlers/promote_integration_events.ex`
- Modify: `lib/klass_hero/enrollment/application/commands/create_enrollment.ex`
- Modify: `lib/klass_hero/enrollment/application/commands/cancel_enrollment_by_admin.ex`
- Modify: `lib/klass_hero/application.ex`

- [ ] **Step 1: Add `enrollment_created` promotion handler**

Add to `lib/klass_hero/enrollment/adapters/driving/events/event_handlers/promote_integration_events.ex`, after the `enrollment_cancelled` clause:

```elixir
  def handle(%DomainEvent{event_type: :enrollment_created} = event) do
    # Trigger: enrollment_created domain event dispatched from CreateEnrollment use case
    # Why: downstream contexts (e.g., Messaging) need to react to new enrollments
    # Outcome: publish integration event on topic integration:enrollment:enrollment_created
    event.payload.enrollment_id
    |> EnrollmentIntegrationEvents.enrollment_created(event.payload)
    |> IntegrationEventPublishing.publish_critical("enrollment_created",
      enrollment_id: event.payload.enrollment_id
    )
  end
```

- [ ] **Step 2: Register `enrollment_created` on the Enrollment DomainEventBus**

In `lib/klass_hero/application.ex`, find the `:enrollment_domain_event_bus` child spec (around line 123). Add the new handler after the `enrollment_cancelled` entry:

```elixir
           {:enrollment_created,
            {KlassHero.Enrollment.Adapters.Driving.Events.EventHandlers.PromoteIntegrationEvents, :handle},
            priority: 10}
```

- [ ] **Step 3: Dispatch `enrollment_created` from `CreateEnrollment`**

In `lib/klass_hero/enrollment/application/commands/create_enrollment.ex`:

Add at the top, below the existing aliases:
```elixir
  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Shared.EventDispatchHelper
```

Add a module attribute for the context:
```elixir
  @context KlassHero.Enrollment
```

Replace the `create_enrollment_with_validation` function to dispatch the event after successful creation:

```elixir
  defp create_enrollment_with_validation(identity_id, params) do
    with {:ok, parent} <- validate_parent_profile(identity_id),
         :ok <- validate_booking_entitlement(parent),
         :ok <- validate_participant_eligibility(params[:program_id], params[:child_id]),
         {:ok, enrollment} <-
           build_enrollment_attrs(params, parent.id)
           |> then(&@enrollment_repository.create_with_capacity_check(&1, params[:program_id])) do
      dispatch_enrollment_created(enrollment, identity_id)
      {:ok, enrollment}
    end
  end
```

Replace the `create_enrollment_direct` function:

```elixir
  defp create_enrollment_direct(params) do
    attrs = build_enrollment_attrs(params, params[:parent_id])

    Logger.info("[Enrollment.CreateEnrollment] Creating enrollment (direct)",
      program_id: attrs[:program_id],
      child_id: attrs[:child_id],
      parent_id: attrs[:parent_id]
    )

    case @enrollment_repository.create_with_capacity_check(attrs, params[:program_id]) do
      {:ok, enrollment} ->
        dispatch_enrollment_created(enrollment, params[:identity_id])
        {:ok, enrollment}

      error ->
        error
    end
  end
```

Add the private dispatch helper:

```elixir
  defp dispatch_enrollment_created(enrollment, identity_id) do
    EnrollmentEvents.enrollment_created(enrollment.id, %{
      enrollment_id: enrollment.id,
      child_id: enrollment.child_id,
      parent_id: enrollment.parent_id,
      parent_user_id: identity_id,
      program_id: enrollment.program_id,
      status: enrollment.status
    })
    |> EventDispatchHelper.dispatch(@context)
  end
```

- [ ] **Step 4: Add `parent_user_id` to `enrollment_cancelled` payload**

In `lib/klass_hero/enrollment/application/commands/cancel_enrollment_by_admin.ex`, the event dispatch at line 56–64 currently doesn't include `parent_user_id`. We need to resolve it. The simplest approach: the `enrollment_cancelled` event already carries `parent_id` — the Messaging handler can look up `identity_id` from its own `messaging_enrolled_children` table (which stores `parent_user_id`). No change needed to this command.

**Verify via Tidewave:** Use `get_ecto_schemas` to confirm the `enrollments` table doesn't store `identity_id` directly. The `parent_user_id` mapping lives in the `messaging_enrolled_children` projection, so the EnrolledChildren handler can use its own data to find affected conversations when processing `enrollment_cancelled`.

- [ ] **Step 5: Run all Enrollment event tests**

Run: `mix test test/klass_hero/enrollment/domain/events/ --max-failures 3`
Expected: All tests pass

- [ ] **Step 6: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation with no warnings

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero/enrollment/adapters/driving/events/event_handlers/promote_integration_events.ex \
        lib/klass_hero/enrollment/application/commands/create_enrollment.ex \
        lib/klass_hero/application.ex
git commit -m "feat: wire enrollment_created event promotion and dispatch"
```

---

### Task 3: Family `child_created` and `child_updated` Events

**Files:**
- Create: `test/klass_hero/family/domain/events/family_events_child_lifecycle_test.exs`
- Create: `test/klass_hero/family/domain/events/family_integration_events_child_lifecycle_test.exs`
- Modify: `lib/klass_hero/family/domain/events/family_events.ex`
- Modify: `lib/klass_hero/family/domain/events/family_integration_events.ex`
- Modify: `lib/klass_hero/family/adapters/driving/events/event_handlers/promote_integration_events.ex`
- Modify: `lib/klass_hero/family/application/commands/children/create_child.ex`
- Modify: `lib/klass_hero/family/application/commands/children/update_child.ex`
- Modify: `lib/klass_hero/application.ex`

- [ ] **Step 1: Write failing tests for `child_created` and `child_updated` domain events**

```elixir
# test/klass_hero/family/domain/events/family_events_child_lifecycle_test.exs
defmodule KlassHero.Family.Domain.Events.FamilyEventsChildLifecycleTest do
  use ExUnit.Case, async: true

  alias KlassHero.Family.Domain.Events.FamilyEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent

  describe "child_created/3" do
    test "creates event with correct type and aggregate" do
      child_id = Ecto.UUID.generate()

      payload = %{
        child_id: child_id,
        parent_id: Ecto.UUID.generate(),
        first_name: "Emma",
        last_name: "Johnson"
      }

      event = FamilyEvents.child_created(child_id, payload)

      assert %DomainEvent{} = event
      assert event.event_type == :child_created
      assert event.aggregate_id == child_id
      assert event.aggregate_type == :child
      assert event.payload.child_id == child_id
      assert event.payload.first_name == "Emma"
    end

    test "base_payload child_id wins over caller-supplied child_id" do
      real_id = Ecto.UUID.generate()
      payload = %{child_id: "should-be-overridden", first_name: "Emma"}

      event = FamilyEvents.child_created(real_id, payload)

      assert event.payload.child_id == real_id
      assert event.payload.first_name == "Emma"
    end

    test "raises for nil child_id" do
      assert_raise ArgumentError, ~r/requires a non-empty child_id string/,
        fn -> FamilyEvents.child_created(nil) end
    end

    test "raises for empty string child_id" do
      assert_raise ArgumentError, ~r/requires a non-empty child_id string/,
        fn -> FamilyEvents.child_created("") end
    end
  end

  describe "child_updated/3" do
    test "creates event with correct type and aggregate" do
      child_id = Ecto.UUID.generate()

      payload = %{
        child_id: child_id,
        parent_id: Ecto.UUID.generate(),
        first_name: "Emily",
        last_name: "Johnson"
      }

      event = FamilyEvents.child_updated(child_id, payload)

      assert %DomainEvent{} = event
      assert event.event_type == :child_updated
      assert event.aggregate_id == child_id
      assert event.aggregate_type == :child
      assert event.payload.first_name == "Emily"
    end

    test "raises for empty string child_id" do
      assert_raise ArgumentError, ~r/requires a non-empty child_id string/,
        fn -> FamilyEvents.child_updated("") end
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/family/domain/events/family_events_child_lifecycle_test.exs --max-failures 1`
Expected: FAIL — `child_created/2` is undefined

- [ ] **Step 3: Implement `child_created` and `child_updated` domain event factories**

Add to `lib/klass_hero/family/domain/events/family_events.ex`, after the `invite_family_ready` function:

```elixir
  @doc """
  Creates a `child_created` event.

  Emitted after the Family context creates a new child record.
  Downstream contexts can react to this event to populate projections.

  ## Parameters

  - `child_id` - The ID of the newly created child
  - `payload` - Event data including parent_id, first_name, last_name
  - `opts` - Metadata options (correlation_id, causation_id, user_id)
  """
  def child_created(child_id, payload \\ %{}, opts \\ [])

  def child_created(child_id, payload, opts) when is_binary(child_id) and byte_size(child_id) > 0 do
    base_payload = %{child_id: child_id}

    DomainEvent.new(
      :child_created,
      child_id,
      @aggregate_type,
      Map.merge(payload, base_payload),
      opts
    )
  end

  def child_created(child_id, _payload, _opts) do
    raise ArgumentError,
          "child_created/3 requires a non-empty child_id string, got: #{inspect(child_id)}"
  end

  @doc """
  Creates a `child_updated` event.

  Emitted after the Family context updates an existing child record.
  Downstream contexts can react to name changes.

  ## Parameters

  - `child_id` - The ID of the updated child
  - `payload` - Event data including parent_id, first_name, last_name
  - `opts` - Metadata options (correlation_id, causation_id, user_id)
  """
  def child_updated(child_id, payload \\ %{}, opts \\ [])

  def child_updated(child_id, payload, opts) when is_binary(child_id) and byte_size(child_id) > 0 do
    base_payload = %{child_id: child_id}

    DomainEvent.new(
      :child_updated,
      child_id,
      @aggregate_type,
      Map.merge(payload, base_payload),
      opts
    )
  end

  def child_updated(child_id, _payload, _opts) do
    raise ArgumentError,
          "child_updated/3 requires a non-empty child_id string, got: #{inspect(child_id)}"
  end
```

Update the `@moduledoc` to include:
```
  - `:child_created` - Emitted when a new child record is created.
  - `:child_updated` - Emitted when a child record is updated.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/family/domain/events/family_events_child_lifecycle_test.exs`
Expected: 6 tests, 0 failures

- [ ] **Step 5: Write failing test for integration events**

```elixir
# test/klass_hero/family/domain/events/family_integration_events_child_lifecycle_test.exs
defmodule KlassHero.Family.Domain.Events.FamilyIntegrationEventsChildLifecycleTest do
  use ExUnit.Case, async: true

  alias KlassHero.Family.Domain.Events.FamilyIntegrationEvents
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  describe "child_created/3" do
    test "creates integration event with correct structure" do
      child_id = Ecto.UUID.generate()
      payload = %{child_id: child_id, parent_id: Ecto.UUID.generate(), first_name: "Emma", last_name: "Johnson"}

      event = FamilyIntegrationEvents.child_created(child_id, payload)

      assert %IntegrationEvent{} = event
      assert event.event_type == :child_created
      assert event.source_context == :family
      assert event.entity_type == :child
      assert event.entity_id == child_id
      assert event.payload.first_name == "Emma"
    end

    test "raises for empty string child_id" do
      assert_raise ArgumentError, ~r/requires a non-empty child_id string/,
        fn -> FamilyIntegrationEvents.child_created("") end
    end
  end

  describe "child_updated/3" do
    test "creates integration event with correct structure" do
      child_id = Ecto.UUID.generate()
      payload = %{child_id: child_id, parent_id: Ecto.UUID.generate(), first_name: "Emily", last_name: "Johnson"}

      event = FamilyIntegrationEvents.child_updated(child_id, payload)

      assert %IntegrationEvent{} = event
      assert event.event_type == :child_updated
      assert event.source_context == :family
      assert event.entity_type == :child
      assert event.entity_id == child_id
      assert event.payload.first_name == "Emily"
    end

    test "raises for empty string child_id" do
      assert_raise ArgumentError, ~r/requires a non-empty child_id string/,
        fn -> FamilyIntegrationEvents.child_updated("") end
    end
  end
end
```

- [ ] **Step 6: Implement integration event factories + promotion handlers + command dispatch + DomainEventBus wiring**

**Integration events** — add to `lib/klass_hero/family/domain/events/family_integration_events.ex`:

```elixir
  @typedoc "Payload for `:child_created` events."
  @type child_created_payload :: %{
          required(:child_id) => String.t(),
          optional(atom()) => term()
        }

  @typedoc "Payload for `:child_updated` events."
  @type child_updated_payload :: %{
          required(:child_id) => String.t(),
          optional(atom()) => term()
        }

  def child_created(child_id, payload \\ %{}, opts \\ [])

  def child_created(child_id, payload, opts) when is_binary(child_id) and byte_size(child_id) > 0 do
    base_payload = %{child_id: child_id}

    IntegrationEvent.new(
      :child_created,
      @source_context,
      @entity_type,
      child_id,
      Map.merge(payload, base_payload),
      opts
    )
  end

  def child_created(child_id, _payload, _opts) do
    raise ArgumentError,
          "child_created/3 requires a non-empty child_id string, got: #{inspect(child_id)}"
  end

  def child_updated(child_id, payload \\ %{}, opts \\ [])

  def child_updated(child_id, payload, opts) when is_binary(child_id) and byte_size(child_id) > 0 do
    base_payload = %{child_id: child_id}

    IntegrationEvent.new(
      :child_updated,
      @source_context,
      @entity_type,
      child_id,
      Map.merge(payload, base_payload),
      opts
    )
  end

  def child_updated(child_id, _payload, _opts) do
    raise ArgumentError,
          "child_updated/3 requires a non-empty child_id string, got: #{inspect(child_id)}"
  end
```

**Promotion handlers** — add to `lib/klass_hero/family/adapters/driving/events/event_handlers/promote_integration_events.ex`:

```elixir
  def handle(%DomainEvent{event_type: :child_created} = event) do
    # Trigger: child_created domain event dispatched from CreateChild use case
    # Why: downstream contexts (e.g., Messaging) need child names for projections
    # Outcome: publish integration event on topic integration:family:child_created
    event.payload.child_id
    |> FamilyIntegrationEvents.child_created(event.payload)
    |> IntegrationEventPublishing.publish()
  end

  def handle(%DomainEvent{event_type: :child_updated} = event) do
    # Trigger: child_updated domain event dispatched from UpdateChild use case
    # Why: downstream contexts need updated child names for projections
    # Outcome: publish integration event on topic integration:family:child_updated
    event.payload.child_id
    |> FamilyIntegrationEvents.child_updated(event.payload)
    |> IntegrationEventPublishing.publish()
  end
```

**DomainEventBus wiring** — in `lib/klass_hero/application.ex`, find the `:family_domain_event_bus` child spec (around line 84). Add after the `invite_family_ready` entry:

```elixir
           {:child_created,
            {KlassHero.Family.Adapters.Driving.Events.EventHandlers.PromoteIntegrationEvents, :handle}, priority: 10},
           {:child_updated,
            {KlassHero.Family.Adapters.Driving.Events.EventHandlers.PromoteIntegrationEvents, :handle}, priority: 10}
```

**Dispatch from CreateChild** — in `lib/klass_hero/family/application/commands/children/create_child.ex`, add aliases and dispatch:

```elixir
  alias KlassHero.Family.Domain.Events.FamilyEvents
  alias KlassHero.Shared.EventDispatchHelper

  @context KlassHero.Family
```

Update `execute/1` to dispatch after successful creation:

```elixir
  def execute(attrs) when is_map(attrs) do
    {parent_id, child_attrs} = Map.pop(attrs, :parent_id)
    child_attrs = Map.put_new(child_attrs, :id, Ecto.UUID.generate())

    with {:ok, _validated} <- Child.new(child_attrs),
         {:ok, persisted} <- persist_child(child_attrs, parent_id) do
      dispatch_child_created(persisted, parent_id)
      {:ok, persisted}
    else
      {:error, errors} when is_list(errors) -> {:error, {:validation_error, errors}}
      {:error, _} = error -> error
    end
  end

  defp dispatch_child_created(child, parent_id) do
    FamilyEvents.child_created(child.id, %{
      child_id: child.id,
      parent_id: parent_id,
      first_name: child.first_name,
      last_name: child.last_name
    })
    |> EventDispatchHelper.dispatch(@context)
  end
```

**Dispatch from UpdateChild** — in `lib/klass_hero/family/application/commands/children/update_child.ex`:

```elixir
  alias KlassHero.Family.Domain.Events.FamilyEvents
  alias KlassHero.Shared.EventDispatchHelper

  @context KlassHero.Family
```

Update `execute/2`:

```elixir
  def execute(child_id, attrs) when is_binary(child_id) and is_map(attrs) do
    with {:ok, existing} <- @repository.get_by_id(child_id),
         merged = Map.merge(Map.from_struct(existing), attrs),
         {:ok, _validated} <- Child.new(merged),
         {:ok, updated} <- @repository.update(child_id, attrs) do
      dispatch_child_updated(updated)
      {:ok, updated}
    else
      {:error, errors} when is_list(errors) -> {:error, {:validation_error, errors}}
      {:error, _} = error -> error
    end
  end

  defp dispatch_child_updated(child) do
    FamilyEvents.child_updated(child.id, %{
      child_id: child.id,
      first_name: child.first_name,
      last_name: child.last_name
    })
    |> EventDispatchHelper.dispatch(@context)
  end
```

Note: `parent_id` is not on the child struct directly (it's in the join table). The `UpdateChild` dispatch omits `parent_id`. The Messaging handler can look up the parent via its own `messaging_enrolled_children` table using `child_id`.

- [ ] **Step 7: Run all Family event tests + verify compilation**

Run: `mix test test/klass_hero/family/domain/events/ && mix compile --warnings-as-errors`
Expected: All tests pass, no compilation warnings

- [ ] **Step 8: Commit**

```bash
git add lib/klass_hero/family/ lib/klass_hero/application.ex \
        test/klass_hero/family/domain/events/family_events_child_lifecycle_test.exs \
        test/klass_hero/family/domain/events/family_integration_events_child_lifecycle_test.exs
git commit -m "feat: add child_created and child_updated domain and integration events"
```

---

### Task 4: Fix `conversation_created` Event to Include `program_id`

**Files:**
- Modify: `lib/klass_hero/messaging/domain/events/messaging_events.ex`
- Modify: `lib/klass_hero/messaging/application/commands/create_direct_conversation.ex`
- Modify: `test/klass_hero_web/live/messaging_live_helper_test.exs` (verify existing tests still pass)

- [ ] **Step 1: Update `conversation_created` domain event to accept `program_id`**

In `lib/klass_hero/messaging/domain/events/messaging_events.ex`, change the `conversation_created` function (around line 28):

```elixir
  @spec conversation_created(
          conversation_id :: String.t(),
          type :: :direct | :program_broadcast,
          provider_id :: String.t(),
          participant_ids :: [String.t()],
          program_id :: String.t() | nil
        ) :: DomainEvent.t()
  def conversation_created(conversation_id, type, provider_id, participant_ids, program_id \\ nil) do
    DomainEvent.new(
      :conversation_created,
      conversation_id,
      @aggregate_type,
      %{
        conversation_id: conversation_id,
        type: type,
        provider_id: provider_id,
        participant_ids: participant_ids,
        program_id: program_id
      }
    )
  end
```

- [ ] **Step 2: Update `CreateDirectConversation` to pass `program_id`**

In `lib/klass_hero/messaging/application/commands/create_direct_conversation.ex`, update `publish_event/3` (around line 113) to accept and pass `program_id`:

```elixir
  defp publish_event(conversation, participant_ids, provider_id) do
    event =
      MessagingEvents.conversation_created(
        conversation.id,
        conversation.type,
        provider_id,
        participant_ids,
        conversation.program_id
      )

    DomainEventBus.dispatch(@context, event)
    :ok
  end
```

- [ ] **Step 3: Verify compilation and existing tests**

Run: `mix compile --warnings-as-errors && mix test test/klass_hero_web/live/messaging_live_helper_test.exs`
Expected: Clean compile, existing tests pass

- [ ] **Step 4: Verify via Tidewave that the event carries program_id**

Use Tidewave `project_eval` to verify:
```elixir
alias KlassHero.Messaging.Domain.Events.MessagingEvents
event = MessagingEvents.conversation_created("conv-1", :direct, "prov-1", ["u1", "u2"], "prog-1")
event.payload.program_id
```
Expected: `"prog-1"`

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/messaging/domain/events/messaging_events.ex \
        lib/klass_hero/messaging/application/commands/create_direct_conversation.ex
git commit -m "fix: include program_id in conversation_created event payload"
```

---

### Task 5: Database Migrations

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_messaging_enrolled_children.exs`
- Create: `priv/repo/migrations/TIMESTAMP_add_enrolled_child_names_to_conversation_summaries.exs`

- [ ] **Step 1: Generate the messaging_enrolled_children migration**

Run: `mix ecto.gen.migration create_messaging_enrolled_children`

Then replace the generated content with:

```elixir
defmodule KlassHero.Repo.Migrations.CreateMessagingEnrolledChildren do
  use Ecto.Migration

  def change do
    create table(:messaging_enrolled_children, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :parent_user_id, :binary_id, null: false
      add :program_id, :binary_id, null: false
      add :child_id, :binary_id, null: false
      add :child_first_name, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:messaging_enrolled_children, [:parent_user_id, :program_id, :child_id])
    create index(:messaging_enrolled_children, [:parent_user_id, :program_id])
    create index(:messaging_enrolled_children, [:child_id])
  end
end
```

- [ ] **Step 2: Generate the conversation_summaries migration**

Run: `mix ecto.gen.migration add_enrolled_child_names_to_conversation_summaries`

Then replace the generated content with:

```elixir
defmodule KlassHero.Repo.Migrations.AddEnrolledChildNamesToConversationSummaries do
  use Ecto.Migration

  def change do
    alter table(:conversation_summaries) do
      add :enrolled_child_names, {:array, :string}, default: []
    end
  end
end
```

- [ ] **Step 3: Run migrations**

Run: `mix ecto.migrate`
Expected: Both migrations applied successfully

- [ ] **Step 4: Verify via Tidewave**

Use Tidewave `execute_sql_query`:
```sql
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'messaging_enrolled_children' ORDER BY ordinal_position;
```
Expected: columns include `parent_user_id`, `program_id`, `child_id`, `child_first_name`

Use Tidewave `execute_sql_query`:
```sql
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'conversation_summaries' AND column_name = 'enrolled_child_names';
```
Expected: one row with `data_type = 'ARRAY'`

- [ ] **Step 5: Commit**

```bash
git add priv/repo/migrations/
git commit -m "feat: add messaging_enrolled_children table and enrolled_child_names column"
```

---

### Task 6: EnrolledChildren Schema + Projection GenServer

**Files:**
- Create: `lib/klass_hero/messaging/adapters/driven/persistence/schemas/enrolled_children_schema.ex`
- Create: `lib/klass_hero/messaging/adapters/driven/projections/enrolled_children.ex`
- Create: `test/klass_hero/messaging/adapters/driven/projections/enrolled_children_test.exs`

- [ ] **Step 1: Write failing test for EnrolledChildren projection bootstrap**

```elixir
# test/klass_hero/messaging/adapters/driven/projections/enrolled_children_test.exs
defmodule KlassHero.Messaging.Adapters.Driven.Projections.EnrolledChildrenTest do
  use KlassHero.DataCase, async: false

  import Ecto.Query
  import KlassHero.Factory

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.EnrolledChildrenSchema
  alias KlassHero.Messaging.Adapters.Driven.Projections.EnrolledChildren
  alias KlassHero.Repo

  @test_server_name :enrolled_children_projection_test

  setup do
    pid = start_supervised!({EnrolledChildren, name: @test_server_name})
    {:ok, pid: pid}
  end

  describe "bootstrap" do
    test "projects existing enrollments into messaging_enrolled_children on startup" do
      # Create a parent with a child enrolled in a program
      user = user_fixture(name: "Sarah Johnson")
      parent = insert(:parent_profile_schema, identity_id: user.id)
      child = insert(:child_schema, first_name: "Emma", last_name: "Johnson")
      insert(:child_guardian_schema, child_id: child.id, guardian_id: parent.id)
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)

      insert(:enrollment_schema,
        parent_id: parent.id,
        child_id: child.id,
        program_id: program.id,
        status: "confirmed"
      )

      # Trigger a rebuild to pick up the test data
      EnrolledChildren.rebuild(@test_server_name)

      # Verify the projection populated
      rows =
        from(e in EnrolledChildrenSchema,
          where: e.parent_user_id == ^user.id and e.program_id == ^program.id
        )
        |> Repo.all()

      assert length(rows) == 1
      [row] = rows
      assert row.child_id == child.id
      assert row.child_first_name == "Emma"
    end

    test "ignores cancelled enrollments during bootstrap" do
      user = user_fixture(name: "Bob Smith")
      parent = insert(:parent_profile_schema, identity_id: user.id)
      child = insert(:child_schema, first_name: "Max")
      insert(:child_guardian_schema, child_id: child.id, guardian_id: parent.id)
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)

      insert(:enrollment_schema,
        parent_id: parent.id,
        child_id: child.id,
        program_id: program.id,
        status: "cancelled"
      )

      EnrolledChildren.rebuild(@test_server_name)

      count =
        from(e in EnrolledChildrenSchema,
          where: e.parent_user_id == ^user.id
        )
        |> Repo.aggregate(:count)

      assert count == 0
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/messaging/adapters/driven/projections/enrolled_children_test.exs --max-failures 1`
Expected: FAIL — `EnrolledChildrenSchema` and `EnrolledChildren` modules don't exist

- [ ] **Step 3: Implement the Ecto schema**

```elixir
# lib/klass_hero/messaging/adapters/driven/persistence/schemas/enrolled_children_schema.ex
defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.EnrolledChildrenSchema do
  @moduledoc """
  Ecto schema for the messaging_enrolled_children projection table.

  Write-only from the EnrolledChildren projection's perspective.
  Read-only for handlers that need to derive child names for conversations.
  """

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: false}
  @timestamps_opts [type: :utc_datetime]

  schema "messaging_enrolled_children" do
    field :parent_user_id, :binary_id
    field :program_id, :binary_id
    field :child_id, :binary_id
    field :child_first_name, :string

    timestamps()
  end
end
```

- [ ] **Step 4: Implement the EnrolledChildren GenServer**

```elixir
# lib/klass_hero/messaging/adapters/driven/projections/enrolled_children.ex
defmodule KlassHero.Messaging.Adapters.Driven.Projections.EnrolledChildren do
  @moduledoc """
  Event-driven projection maintaining the `messaging_enrolled_children` lookup table.

  This GenServer subscribes to cross-context integration events from
  Enrollment and Family, plus Messaging's own `conversation_created` event.
  It maintains a local lookup of enrolled children per parent+program,
  then emits `enrolled_children_changed` domain events that the
  `ConversationSummaries` projection consumes.

  ## Event Subscriptions

  - `integration:enrollment:enrollment_created` — upserts a lookup row
  - `integration:enrollment:enrollment_cancelled` — deletes a lookup row
  - `integration:family:child_created` — updates child_first_name
  - `integration:family:child_updated` — updates child_first_name
  - `integration:messaging:conversation_created` — triggers name resolution for new conversations
  """

  use GenServer

  import Ecto.Query

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSummarySchema
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.EnrolledChildrenSchema
  alias KlassHero.Repo
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  require Logger

  @enrollment_created_topic "integration:enrollment:enrollment_created"
  @enrollment_cancelled_topic "integration:enrollment:enrollment_cancelled"
  @child_created_topic "integration:family:child_created"
  @child_updated_topic "integration:family:child_updated"
  @conversation_created_topic "integration:messaging:conversation_created"

  @enrolled_children_changed_topic "messaging:enrolled_children_changed"

  # Client API

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec rebuild(GenServer.name()) :: :ok
  def rebuild(name \\ __MODULE__) do
    GenServer.call(name, :rebuild, :infinity)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @enrollment_created_topic)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @enrollment_cancelled_topic)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @child_created_topic)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @child_updated_topic)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @conversation_created_topic)

    {:ok, %{bootstrapped: false}, {:continue, :bootstrap}}
  end

  @impl true
  def handle_continue(:bootstrap, state) do
    attempt_bootstrap(state)
  end

  @impl true
  def handle_call(:rebuild, _from, state) do
    count = bootstrap_from_write_tables()
    Logger.info("EnrolledChildren rebuilt", count: count)
    {:reply, :ok, %{state | bootstrapped: true}}
  end

  @impl true
  def handle_info(:retry_bootstrap, state) do
    {:noreply, state, {:continue, :bootstrap}}
  end

  # Trigger: enrollment_created integration event
  # Why: new enrollment means a child is now enrolled in a program
  # Outcome: upsert row in lookup table, re-derive child names
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :enrollment_created} = event}, state) do
    Logger.debug("EnrolledChildren projecting enrollment_created",
      enrollment_id: event.entity_id
    )

    project_enrollment_created(event)
    {:noreply, state}
  end

  # Trigger: enrollment_cancelled integration event
  # Why: child is no longer enrolled, remove from lookup
  # Outcome: delete row from lookup table, re-derive child names
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :enrollment_cancelled} = event}, state) do
    Logger.debug("EnrolledChildren projecting enrollment_cancelled",
      enrollment_id: event.entity_id
    )

    project_enrollment_cancelled(event)
    {:noreply, state}
  end

  # Trigger: child_created integration event
  # Why: fills in child_first_name for rows that may have nil
  # Outcome: update child_first_name, re-derive child names
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :child_created} = event}, state) do
    Logger.debug("EnrolledChildren projecting child_created",
      child_id: event.entity_id
    )

    project_child_name_change(event)
    {:noreply, state}
  end

  # Trigger: child_updated integration event
  # Why: child name may have changed, update in lookup
  # Outcome: update child_first_name, re-derive child names
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :child_updated} = event}, state) do
    Logger.debug("EnrolledChildren projecting child_updated",
      child_id: event.entity_id
    )

    project_child_name_change(event)
    {:noreply, state}
  end

  # Trigger: conversation_created integration event
  # Why: new direct conversation with program_id needs enrolled child names
  # Outcome: look up names from table, emit enrolled_children_changed
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :conversation_created} = event}, state) do
    project_conversation_created(event)
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("EnrolledChildren received unexpected message",
      message: inspect(msg, limit: 200)
    )

    {:noreply, state}
  end

  # Private Functions — Bootstrap

  defp attempt_bootstrap(state) do
    count = bootstrap_from_write_tables()
    Logger.info("EnrolledChildren projection started", count: count)
    {:noreply, %{state | bootstrapped: true}}
  rescue
    error ->
      retry_count = Map.get(state, :retry_count, 0) + 1

      if retry_count > 3 do
        reraise error, __STACKTRACE__
      else
        Logger.error("EnrolledChildren: bootstrap failed, scheduling retry",
          error: Exception.message(error),
          retry_count: retry_count
        )

        Process.send_after(self(), :retry_bootstrap, 5_000 * retry_count)
        {:noreply, Map.put(state, :retry_count, retry_count)}
      end
  end

  defp bootstrap_from_write_tables do
    entries =
      from(e in "enrollments",
        join: c in "children", on: c.id == e.child_id,
        join: pp in "parent_profiles", on: pp.id == e.parent_id,
        where: e.status in ["pending", "confirmed"],
        select: %{
          parent_user_id: type(pp.identity_id, :binary_id),
          program_id: type(e.program_id, :binary_id),
          child_id: type(e.child_id, :binary_id),
          child_first_name: c.first_name
        }
      )
      |> Repo.all()

    if entries == [] do
      0
    else
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      rows =
        Enum.map(entries, fn entry ->
          Map.merge(entry, %{id: Ecto.UUID.generate(), inserted_at: now, updated_at: now})
        end)

      {count, _} =
        Repo.insert_all(EnrolledChildrenSchema, rows,
          on_conflict: {:replace, [:child_first_name, :updated_at]},
          conflict_target: [:parent_user_id, :program_id, :child_id]
        )

      count
    end
  end

  # Private Functions — Event Projections

  defp project_enrollment_created(event) do
    payload = event.payload
    parent_user_id = payload.parent_user_id
    program_id = payload.program_id
    child_id = payload.child_id
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %EnrolledChildrenSchema{}
    |> Ecto.Changeset.change(%{
      id: Ecto.UUID.generate(),
      parent_user_id: parent_user_id,
      program_id: program_id,
      child_id: child_id,
      child_first_name: nil,
      inserted_at: now,
      updated_at: now
    })
    |> Repo.insert!(
      on_conflict: {:replace, [:updated_at]},
      conflict_target: [:parent_user_id, :program_id, :child_id]
    )

    re_derive_and_emit(parent_user_id, program_id)
  end

  defp project_enrollment_cancelled(event) do
    payload = event.payload
    child_id = payload.child_id
    program_id = payload.program_id

    # Trigger: find the lookup row via child_id + program_id
    # Why: enrollment_cancelled doesn't carry parent_user_id
    # Outcome: delete the row and re-derive for the affected parent+program
    rows =
      from(e in EnrolledChildrenSchema,
        where: e.child_id == ^child_id and e.program_id == ^program_id,
        select: e
      )
      |> Repo.all()

    case rows do
      [row | _] ->
        from(e in EnrolledChildrenSchema,
          where: e.child_id == ^child_id and e.program_id == ^program_id
        )
        |> Repo.delete_all()

        re_derive_and_emit(row.parent_user_id, program_id)

      [] ->
        :ok
    end
  end

  defp project_child_name_change(event) do
    payload = event.payload
    child_id = payload.child_id
    first_name = payload.first_name
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Trigger: child name changed (created or updated)
    # Why: update all lookup rows for this child_id
    # Outcome: child_first_name updated, then re-derive for each affected parent+program
    affected =
      from(e in EnrolledChildrenSchema,
        where: e.child_id == ^child_id,
        select: {e.parent_user_id, e.program_id}
      )
      |> Repo.all()

    if affected != [] do
      from(e in EnrolledChildrenSchema,
        where: e.child_id == ^child_id
      )
      |> Repo.update_all(set: [child_first_name: first_name, updated_at: now])

      affected
      |> Enum.uniq()
      |> Enum.each(fn {parent_user_id, program_id} ->
        re_derive_and_emit(parent_user_id, program_id)
      end)
    end
  end

  defp project_conversation_created(event) do
    payload = event.payload
    program_id = Map.get(payload, :program_id)
    conversation_type = payload |> Map.get(:type, "direct") |> to_string()

    # Trigger: only direct conversations with a program_id need child names
    # Why: broadcast conversations don't show per-parent child context
    # Outcome: skip if not direct or no program_id
    if conversation_type == "direct" and program_id do
      participant_ids = Map.get(payload, :participant_ids, [])
      conversation_id = payload.conversation_id

      # Trigger: check each participant for enrolled children
      # Why: one of the participants is the parent, the other is the provider
      # Outcome: emit enrolled_children_changed for any participant with enrolled children
      Enum.each(participant_ids, fn user_id ->
        child_names = get_child_names(user_id, program_id)

        if child_names != [] do
          emit_enrolled_children_changed(conversation_id, child_names)
        end
      end)
    end
  end

  # Private Functions — Re-derivation

  defp re_derive_and_emit(parent_user_id, program_id) do
    child_names = get_child_names(parent_user_id, program_id)

    # Trigger: find all direct conversations for this parent+program
    # Why: each conversation needs its enrolled_child_names updated
    # Outcome: emit enrolled_children_changed for each affected conversation
    conversation_ids =
      from(s in ConversationSummarySchema,
        where:
          s.user_id == ^parent_user_id and
            s.program_id == ^program_id and
            s.conversation_type == "direct",
        select: s.conversation_id,
        distinct: true
      )
      |> Repo.all()

    Enum.each(conversation_ids, fn conversation_id ->
      emit_enrolled_children_changed(conversation_id, child_names)
    end)
  end

  defp get_child_names(parent_user_id, program_id) do
    from(e in EnrolledChildrenSchema,
      where:
        e.parent_user_id == ^parent_user_id and
          e.program_id == ^program_id and
          not is_nil(e.child_first_name),
      select: e.child_first_name,
      order_by: e.child_first_name
    )
    |> Repo.all()
  end

  defp emit_enrolled_children_changed(conversation_id, child_names) do
    event =
      DomainEvent.new(
        :enrolled_children_changed,
        conversation_id,
        :conversation,
        %{
          conversation_id: conversation_id,
          enrolled_child_names: child_names
        }
      )

    Phoenix.PubSub.broadcast(
      KlassHero.PubSub,
      @enrolled_children_changed_topic,
      {:domain_event, event}
    )
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/klass_hero/messaging/adapters/driven/projections/enrolled_children_test.exs`
Expected: 2 tests, 0 failures

**Verify via Tidewave:** Use `get_ecto_schemas` to confirm the `EnrolledChildrenSchema` is correctly loaded.

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/messaging/adapters/driven/persistence/schemas/enrolled_children_schema.ex \
        lib/klass_hero/messaging/adapters/driven/projections/enrolled_children.ex \
        test/klass_hero/messaging/adapters/driven/projections/enrolled_children_test.exs
git commit -m "feat: add EnrolledChildren projection with schema and bootstrap"
```

---

### Task 7: Extend ConversationSummaries — Schema, Read Model, and Event Handler

**Files:**
- Modify: `lib/klass_hero/messaging/adapters/driven/persistence/schemas/conversation_summary_schema.ex`
- Modify: `lib/klass_hero/messaging/domain/read_models/conversation_summary.ex`
- Modify: `lib/klass_hero/messaging/adapters/driven/persistence/repositories/conversation_summaries_repository.ex`
- Modify: `lib/klass_hero/messaging/adapters/driven/projections/conversation_summaries.ex`

- [ ] **Step 1: Add `enrolled_child_names` to ConversationSummarySchema**

In `lib/klass_hero/messaging/adapters/driven/persistence/schemas/conversation_summary_schema.ex`, add after the `system_notes` field:

```elixir
    field :enrolled_child_names, {:array, :string}, default: []
```

- [ ] **Step 2: Add `enrolled_child_names` to ConversationSummary read model**

In `lib/klass_hero/messaging/domain/read_models/conversation_summary.ex`:

Add to the `@type` spec (after `archived_at`):
```elixir
          enrolled_child_names: [String.t()],
```

Add to `defstruct` (after `unread_count: 0`):
```elixir
    enrolled_child_names: [],
```

- [ ] **Step 3: Map `enrolled_child_names` in `to_dto/1`**

In `lib/klass_hero/messaging/adapters/driven/persistence/repositories/conversation_summaries_repository.ex`, add to the `to_dto/1` function (around line 235, after `archived_at`):

```elixir
      enrolled_child_names: schema.enrolled_child_names || [],
```

- [ ] **Step 4: Subscribe ConversationSummaries to the new PubSub topic and handle the event**

In `lib/klass_hero/messaging/adapters/driven/projections/conversation_summaries.ex`:

Add the topic module attribute near the top (after line 57):
```elixir
  @enrolled_children_changed_topic "messaging:enrolled_children_changed"
```

Subscribe in `init/1` (after the existing subscribes, around line 98):
```elixir
    Phoenix.PubSub.subscribe(KlassHero.PubSub, @enrolled_children_changed_topic)
```

Add a new `handle_info` clause (after the `message_data_anonymized` clause, before the catch-all):

```elixir
  # Trigger: Received an enrolled_children_changed domain event from EnrolledChildren projection
  # Why: conversation summary needs updated child names for display
  # Outcome: enrolled_child_names column updated for all rows of the conversation
  @impl true
  def handle_info({:domain_event, %DomainEvent{event_type: :enrolled_children_changed} = event}, state) do
    Logger.debug("ConversationSummaries projecting enrolled_children_changed",
      conversation_id: event.aggregate_id
    )

    project_enrolled_children_changed(event)
    {:noreply, state}
  end
```

Add the alias at the top (after `IntegrationEvent`):
```elixir
  alias KlassHero.Shared.Domain.Events.DomainEvent
```

Add the private function (before the `# Private Functions — System Note Projection` section):

```elixir
  # Trigger: enrolled_children_changed domain event received
  # Why: update the enrolled_child_names for all participant rows of this conversation
  # Outcome: simple field update — projection stays dumb
  defp project_enrolled_children_changed(event) do
    conversation_id = event.payload.conversation_id
    child_names = Map.get(event.payload, :enrolled_child_names, [])
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(s in ConversationSummarySchema,
      where: s.conversation_id == ^conversation_id
    )
    |> Repo.update_all(
      set: [
        enrolled_child_names: child_names,
        updated_at: now
      ]
    )
  end
```

- [ ] **Step 5: Update bootstrap to include `enrolled_child_names`**

In the `build_summary_entry/3` function, add `enrolled_child_names` to the returned map (after `system_notes`):

```elixir
      enrolled_child_names: resolve_enrolled_child_names(conversation, participant.user_id),
```

Add the helper function:

```elixir
  # Trigger: bootstrap needs enrolled child names from the EnrolledChildren projection table
  # Why: direct conversations with a program_id should display child context
  # Outcome: list of child first names or empty list
  defp resolve_enrolled_child_names(%{type: type, program_id: program_id}, user_id)
       when type in ["direct", :direct] and not is_nil(program_id) do
    from(e in KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.EnrolledChildrenSchema,
      where:
        e.parent_user_id == ^user_id and
          e.program_id == ^program_id and
          not is_nil(e.child_first_name),
      select: e.child_first_name,
      order_by: e.child_first_name
    )
    |> Repo.all()
  end

  defp resolve_enrolled_child_names(_, _), do: []
```

- [ ] **Step 6: Run ConversationSummaries tests**

Run: `mix test test/klass_hero/messaging/adapters/driven/projections/conversation_summaries_test.exs`
Expected: All existing tests pass (new field has default `[]`)

- [ ] **Step 7: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation

- [ ] **Step 8: Commit**

```bash
git add lib/klass_hero/messaging/adapters/driven/persistence/schemas/conversation_summary_schema.ex \
        lib/klass_hero/messaging/domain/read_models/conversation_summary.ex \
        lib/klass_hero/messaging/adapters/driven/persistence/repositories/conversation_summaries_repository.ex \
        lib/klass_hero/messaging/adapters/driven/projections/conversation_summaries.ex
git commit -m "feat: extend ConversationSummaries with enrolled_child_names"
```

---

### Task 8: Supervision Wiring

**Files:**
- Modify: `lib/klass_hero/projection_supervisor.ex`

- [ ] **Step 1: Add EnrolledChildren to ProjectionSupervisor**

In `lib/klass_hero/projection_supervisor.ex`, add the alias:
```elixir
  alias KlassHero.Messaging.Adapters.Driven.Projections.EnrolledChildren
```

Add `EnrolledChildren` to the children list **before** `ConversationSummaries` (so it bootstraps first):

```elixir
    children = [
      VerifiedProviders,
      ProgramListings,
      EnrolledChildren,
      ConversationSummaries,
      ProviderSessionStats
    ]
```

- [ ] **Step 2: Verify compilation and server startup**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation

Use Tidewave `project_eval`:
```elixir
Process.whereis(KlassHero.Messaging.Adapters.Driven.Projections.EnrolledChildren) |> is_pid()
```
Expected: `true` (if server is running)

- [ ] **Step 3: Commit**

```bash
git add lib/klass_hero/projection_supervisor.ex
git commit -m "feat: add EnrolledChildren to ProjectionSupervisor"
```

---

### Task 9: Web Layer — `get_conversation_title/3`

**Files:**
- Modify: `test/klass_hero_web/live/messaging_live_helper_test.exs`
- Modify: `lib/klass_hero_web/live/messaging_live_helper.ex`

- [ ] **Step 1: Write failing tests for `get_conversation_title/3`**

Replace the existing `describe "get_conversation_title/1"` block in `test/klass_hero_web/live/messaging_live_helper_test.exs`:

```elixir
  describe "get_conversation_title/3" do
    test "returns parent name with child names for direct conversation with enrolled children" do
      conversation = %{type: :direct}
      child_names = ["Emma", "Liam"]
      other_name = "Sarah Johnson"

      assert MessagingLiveHelper.get_conversation_title(conversation, child_names, other_name) ==
               "Sarah Johnson for Emma, Liam"
    end

    test "returns parent name with single child for direct conversation" do
      conversation = %{type: :direct}

      assert MessagingLiveHelper.get_conversation_title(conversation, ["Emma"], "Sarah Johnson") ==
               "Sarah Johnson for Emma"
    end

    test "returns other participant name when no enrolled children" do
      conversation = %{type: :direct}

      assert MessagingLiveHelper.get_conversation_title(conversation, [], "Sarah Johnson") ==
               "Sarah Johnson"
    end

    test "returns subject for program_broadcast with subject" do
      conversation = %{type: :program_broadcast, subject: "Summer Camp Update"}

      assert MessagingLiveHelper.get_conversation_title(conversation, [], nil) ==
               "Summer Camp Update"
    end

    test "returns 'Program Broadcast' for broadcast without subject" do
      conversation = %{type: :program_broadcast, subject: nil}

      assert MessagingLiveHelper.get_conversation_title(conversation, [], nil) ==
               "Program Broadcast"
    end

    test "returns 'Conversation' as fallback" do
      assert MessagingLiveHelper.get_conversation_title(%{type: :direct}, [], nil) ==
               "Conversation"
    end
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero_web/live/messaging_live_helper_test.exs --max-failures 1`
Expected: FAIL — `get_conversation_title/3` is undefined (only `/1` exists)

- [ ] **Step 3: Implement `get_conversation_title/3`**

In `lib/klass_hero_web/live/messaging_live_helper.ex`, replace the existing three `get_conversation_title/1` clauses (around lines 326–336) with:

```elixir
  @doc """
  Returns the title for a conversation.

  For direct conversations with enrolled children (provider view):
  "Sarah Johnson for Emma, Liam"
  """
  def get_conversation_title(conversation, enrolled_child_names \\ [], other_participant_name \\ nil)

  def get_conversation_title(%{type: :direct}, child_names, other_name)
      when child_names != [] and not is_nil(other_name) do
    formatted = Enum.join(child_names, ", ")
    "#{other_name} #{gettext("for")} #{formatted}"
  end

  def get_conversation_title(%{type: :direct}, _child_names, other_name)
      when not is_nil(other_name) do
    other_name
  end

  def get_conversation_title(%{type: :program_broadcast, subject: subject}, _, _)
      when not is_nil(subject) do
    subject
  end

  def get_conversation_title(%{type: :program_broadcast}, _, _) do
    gettext("Program Broadcast")
  end

  def get_conversation_title(_conversation, _, _) do
    gettext("Conversation")
  end
```

- [ ] **Step 4: Update the caller in `mount_conversation_show`**

In the same file, update the socket assignment block (the part that sets `page_title` around line 139):

Replace:
```elixir
          |> assign(:page_title, get_conversation_title(conversation))
```

With:
```elixir
          |> assign(:page_title, build_page_title(conversation, user_id))
```

Add the helper function that reads from the projection (avoids relying on `conversation.participants` which may not be loaded):

```elixir
  defp build_page_title(conversation, user_id) do
    context = fetch_conversation_context(conversation.id, user_id)
    get_conversation_title(conversation, context.enrolled_child_names, context.other_participant_name)
  end

  defp fetch_conversation_context(conversation_id, user_id) do
    import Ecto.Query

    alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSummarySchema

    case KlassHero.Repo.one(
           from(s in ConversationSummarySchema,
             where: s.conversation_id == ^conversation_id and s.user_id == ^user_id,
             select: %{
               enrolled_child_names: s.enrolled_child_names,
               other_participant_name: s.other_participant_name
             }
           )
         ) do
      nil -> %{enrolled_child_names: [], other_participant_name: nil}
      result -> %{enrolled_child_names: result.enrolled_child_names || [], other_participant_name: result.other_participant_name}
    end
  end
```

Remove the separate `fetch_enrolled_child_names/2` helper — `fetch_conversation_context/2` replaces it.

- [ ] **Step 5: Run tests**

Run: `mix test test/klass_hero_web/live/messaging_live_helper_test.exs`
Expected: All tests pass

- [ ] **Step 6: Run full precommit**

Run: `mix precommit`
Expected: All checks pass

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero_web/live/messaging_live_helper.ex \
        test/klass_hero_web/live/messaging_live_helper_test.exs
git commit -m "feat: update get_conversation_title to show parent name with child names"
```

---

### Task 10: Web Layer — Conversation Card Subtitle (Index View)

**Files:**
- Modify: `lib/klass_hero_web/components/messaging_components.ex`

- [ ] **Step 1: Add `enrolled_child_names` to conversation_card data flow**

First, check how `conversation_card` receives its data. The `conversation_list` component (around line 464) passes `conv_data.other_participant_name`. We need to also pass `enrolled_child_names`.

In `lib/klass_hero_web/components/messaging_components.ex`, find the `conversation_card` component call inside `conversation_list` (around line 467). Add the new attribute:

```elixir
        enrolled_child_names={Map.get(conv_data, :enrolled_child_names, [])}
```

- [ ] **Step 2: Add `enrolled_child_names` attr to `conversation_card` and render subtitle**

Find the `conversation_card` component definition and add the attr:

```elixir
  attr :enrolled_child_names, :list, default: []
```

Inside the card template, below the `other_participant_name` display, add the child names subtitle (only when non-empty):

```heex
<p :if={@enrolled_child_names != []} class={["text-xs mt-0.5", Theme.text_color(:muted)]}>
  {gettext("for")} {Enum.join(@enrolled_child_names, ", ")}
</p>
```

The exact placement depends on the existing card layout — insert it as a subtitle under the name display area. Only show on the provider side.

- [ ] **Step 3: Update `ListConversations.to_enriched_map/1` to include `enrolled_child_names`**

In `lib/klass_hero/messaging/application/queries/list_conversations.ex`, add `enrolled_child_names` to the `to_enriched_map/1` function (after the `other_participant_name` line):

```elixir
      enrolled_child_names: summary.enrolled_child_names
```

The `ConversationSummary` struct already has this field from Task 7. This ensures the data flows through to the template.

- [ ] **Step 4: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero_web/components/messaging_components.ex
git commit -m "feat: show enrolled child names in conversation card subtitle"
```

---

### Task 11: Final Verification and Follow-up Issue

- [ ] **Step 1: Run full test suite**

Run: `mix precommit`
Expected: All checks pass — compile, format, test

- [ ] **Step 2: Verify projection works end-to-end via Tidewave**

Use Tidewave `project_eval` to simulate the flow:
```elixir
# Check if EnrolledChildren projection is running
Process.whereis(KlassHero.Messaging.Adapters.Driven.Projections.EnrolledChildren) |> is_pid()
```

Use Tidewave `execute_sql_query`:
```sql
SELECT * FROM messaging_enrolled_children LIMIT 5;
```

Use Tidewave `execute_sql_query`:
```sql
SELECT conversation_id, enrolled_child_names FROM conversation_summaries WHERE enrolled_child_names != '{}' LIMIT 5;
```

- [ ] **Step 3: File follow-up issue for CQRS show-view migration**

```bash
gh issue create --title "refactor: migrate conversation show view to read from projection" \
  --body "$(cat <<'EOF'
## Context

As part of #551, the conversation show view now reads from two sources:
- Write model (via `GetConversation`) for messages, participants, sender names
- Projection (via `conversation_summaries`) for `enrolled_child_names`

## Goal

Design a dedicated conversation-detail read model/projection that replaces the write-model dependency entirely. This would make the projection layer the single source of truth for the show view.

## Notes

- The current `conversation_summaries` projection is inbox-optimized (one row per user per conversation with latest message only)
- A detail projection would need: full message history (paginated), all sender names, participant identities, mark-as-read capability
- This is a larger CQRS evolution — scope carefully

## Related

- Closes no issue (follow-up from #551)
- Spec: `docs/superpowers/specs/2026-04-17-enrolled-children-projection-design.md` (Follow-up Issue section)
EOF
)"
```

- [ ] **Step 4: Push branch**

```bash
git push -u origin feat/551-show-parent-and-enrolled-child-names-in-conversation
```
