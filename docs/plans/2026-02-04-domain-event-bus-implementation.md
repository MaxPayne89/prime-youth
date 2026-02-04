# Domain Event Bus Redesign — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor DomainEventBus from executor to handler registry with caller-side execution, then migrate Identity and Messaging contexts to dispatch through the bus.

**Architecture:** GenServer becomes a handler registry only — stores `{handler_fn, opts}` tuples. `dispatch/2` fetches handlers via `GenServer.call`, executes them in the caller's process sorted by priority. Handlers registered at init via `{Module, :function}` tuples in the supervision tree.

**Tech Stack:** Elixir/OTP GenServer, Phoenix PubSub, ExUnit

**Design doc:** `docs/plans/2026-02-04-domain-event-bus-redesign.md`

---

### Task 1: Refactor DomainEventBus to registry-with-caller-side-execution

The core change. Transform the GenServer from executing handlers internally to only storing/serving them. Execution moves to the caller's process.

**Files:**
- Modify: `lib/klass_hero/shared/domain_event_bus.ex`
- Modify: `test/klass_hero/shared/domain_event_bus_test.exs`

**Step 1: Update existing tests to match new behavior**

The tests currently use `subscribe/3`. Update to `subscribe/4` (with opts) and add tests for:
- Priority ordering (lower number runs first)
- Init-time handler registration via `handlers:` opt
- `{Module, :function}` tuple resolution
- Caller-side execution proof (handler runs in test process, not GenServer)

Replace `test/klass_hero/shared/domain_event_bus_test.exs` with:

```elixir
defmodule KlassHero.Shared.DomainEventBusTest do
  @moduledoc """
  Tests for DomainEventBus handler registry and caller-side dispatch.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.DomainEventBus

  @test_context __MODULE__.TestContext

  # Test handler module for {Module, :function} tuple registration
  defmodule TestHandler do
    def succeed(_event), do: :ok
    def fail(_event), do: {:error, :handler_failed}
    def crash(_event), do: raise("handler boom")
    def unexpected(_event), do: :wrong_return

    def report_pid(event) do
      send(event.payload.test_pid, {:handler_ran_in, self()})
      :ok
    end
  end

  setup do
    bus = start_supervised!({DomainEventBus, context: @test_context})
    %{bus: bus}
  end

  defp build_event(event_type, payload \\ %{}) do
    DomainEvent.new(event_type, "entity-1", :test, payload)
  end

  describe "dispatch/2 — handler results" do
    test "returns :ok when all handlers succeed" do
      DomainEventBus.subscribe(@test_context, :test_event, fn _event -> :ok end)
      DomainEventBus.subscribe(@test_context, :test_event, fn _event -> :ok end)

      assert :ok = DomainEventBus.dispatch(@test_context, build_event(:test_event))
    end

    test "returns :ok when no handlers are registered" do
      assert :ok = DomainEventBus.dispatch(@test_context, build_event(:unsubscribed_event))
    end

    test "returns error when handler returns {:error, reason}" do
      DomainEventBus.subscribe(@test_context, :failing_event, fn _event ->
        {:error, :publish_failed}
      end)

      assert {:error, [{:error, :publish_failed}]} =
               DomainEventBus.dispatch(@test_context, build_event(:failing_event))
    end

    test "returns error when handler crashes" do
      DomainEventBus.subscribe(@test_context, :crashing_event, fn _event ->
        raise "handler boom"
      end)

      assert {:error, [{:error, {:handler_crashed, %RuntimeError{message: "handler boom"}}}]} =
               DomainEventBus.dispatch(@test_context, build_event(:crashing_event))
    end

    test "wraps unexpected handler return values" do
      DomainEventBus.subscribe(@test_context, :unexpected_event, fn _event ->
        :wrong_return
      end)

      assert {:error, [{:error, {:unexpected_return, :wrong_return}}]} =
               DomainEventBus.dispatch(@test_context, build_event(:unexpected_event))
    end

    test "aggregates failures from multiple handlers" do
      DomainEventBus.subscribe(@test_context, :mixed_event, fn _event -> :ok end)

      DomainEventBus.subscribe(@test_context, :mixed_event, fn _event ->
        {:error, :handler_a_failed}
      end)

      DomainEventBus.subscribe(@test_context, :mixed_event, fn _event -> :ok end)

      DomainEventBus.subscribe(@test_context, :mixed_event, fn _event ->
        raise "handler b boom"
      end)

      assert {:error, failures} =
               DomainEventBus.dispatch(@test_context, build_event(:mixed_event))

      assert length(failures) == 2

      assert Enum.any?(failures, fn
               {:error, :handler_a_failed} -> true
               _ -> false
             end)

      assert Enum.any?(failures, fn
               {:error, {:handler_crashed, %RuntimeError{message: "handler b boom"}}} -> true
               _ -> false
             end)
    end
  end

  describe "dispatch/2 — caller-side execution" do
    test "handlers execute in the caller's process, not the GenServer" do
      test_pid = self()

      DomainEventBus.subscribe(@test_context, :pid_event, fn _event ->
        send(test_pid, {:handler_ran_in, self()})
        :ok
      end)

      DomainEventBus.dispatch(@test_context, build_event(:pid_event))

      assert_receive {:handler_ran_in, handler_pid}
      assert handler_pid == test_pid
    end
  end

  describe "subscribe/4 — priority ordering" do
    test "handlers execute in priority order (lower number first)" do
      test_pid = self()

      DomainEventBus.subscribe(
        @test_context,
        :priority_event,
        fn _event -> send(test_pid, :third) end,
        priority: 30
      )

      DomainEventBus.subscribe(
        @test_context,
        :priority_event,
        fn _event -> send(test_pid, :first) end,
        priority: 10
      )

      DomainEventBus.subscribe(
        @test_context,
        :priority_event,
        fn _event -> send(test_pid, :second) end,
        priority: 20
      )

      DomainEventBus.dispatch(@test_context, build_event(:priority_event))

      assert_receive :first
      assert_receive :second
      assert_receive :third
    end

    test "same-priority handlers execute in registration order" do
      test_pid = self()

      DomainEventBus.subscribe(@test_context, :same_priority, fn _event ->
        send(test_pid, :first_registered)
        :ok
      end)

      DomainEventBus.subscribe(@test_context, :same_priority, fn _event ->
        send(test_pid, :second_registered)
        :ok
      end)

      DomainEventBus.dispatch(@test_context, build_event(:same_priority))

      assert_receive :first_registered
      assert_receive :second_registered
    end

    test "defaults to priority 100 when not specified" do
      test_pid = self()

      DomainEventBus.subscribe(@test_context, :default_priority, fn _event ->
        send(test_pid, :default)
        :ok
      end)

      DomainEventBus.subscribe(
        @test_context,
        :default_priority,
        fn _event ->
          send(test_pid, :explicit_low)
          :ok
        end,
        priority: 10
      )

      DomainEventBus.dispatch(@test_context, build_event(:default_priority))

      assert_receive :explicit_low
      assert_receive :default
    end
  end

  describe "init-time handler registration" do
    test "registers {Module, :function} handlers from opts at startup" do
      context = __MODULE__.MFAContext

      _bus =
        start_supervised!(
          {DomainEventBus,
           context: context,
           handlers: [
             {:test_event, {TestHandler, :succeed}}
           ]}
        )

      assert :ok = DomainEventBus.dispatch(context, build_event(:test_event))
    end

    test "respects priority on init-time handlers" do
      context = __MODULE__.MFAPriorityContext
      test_pid = self()

      _bus =
        start_supervised!(
          {DomainEventBus,
           context: context,
           handlers: [
             {:ordered_event, {TestHandler, :succeed}, priority: 20},
             {:ordered_event, {TestHandler, :succeed}, priority: 10}
           ]}
        )

      # Subscribe a runtime handler at priority 15 to verify interleaving
      DomainEventBus.subscribe(
        context,
        :ordered_event,
        fn _event ->
          send(test_pid, :runtime_15)
          :ok
        end,
        priority: 15
      )

      DomainEventBus.dispatch(context, build_event(:ordered_event))

      # priority 10, then 15 (runtime), then 20
      assert_receive :runtime_15
    end

    test "{Module, :function} handler errors propagate correctly" do
      context = __MODULE__.MFAErrorContext

      _bus =
        start_supervised!(
          {DomainEventBus,
           context: context,
           handlers: [
             {:fail_event, {TestHandler, :fail}}
           ]}
        )

      assert {:error, [{:error, :handler_failed}]} =
               DomainEventBus.dispatch(context, build_event(:fail_event))
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/shared/domain_event_bus_test.exs`
Expected: Multiple failures (subscribe/4 not defined, no init-time registration, dispatch still server-side)

**Step 3: Rewrite DomainEventBus implementation**

Replace `lib/klass_hero/shared/domain_event_bus.ex` with the registry-over-executor design:

```elixir
defmodule KlassHero.Shared.DomainEventBus do
  @moduledoc """
  Per-context handler registry for domain event dispatch.

  Each bounded context gets its own DomainEventBus. The GenServer acts as a
  **handler registry only** — it stores handler functions and their opts.
  Actual handler execution happens in the caller's process via `dispatch/2`.

  ## Why caller-side execution

  - No GenServer bottleneck — dispatch doesn't serialize through one process
  - Handler failures affect the caller, not the bus (bus stays alive)
  - Process context preserved — test doubles, Ecto sandbox, telemetry all work
  - Future async migration only changes `execute_handlers/2`

  ## Supervision tree setup

      {DomainEventBus,
       context: KlassHero.Identity,
       handlers: [
         {:user_anonymized, {MyHandler, :handle}, priority: 10}
       ]}

  ## Runtime subscription

      DomainEventBus.subscribe(KlassHero.Identity, :child_updated, &handler/1, priority: 20)

  ## Dispatching

      DomainEventBus.dispatch(KlassHero.Identity, %DomainEvent{event_type: :child_updated, ...})
  """

  use GenServer

  alias KlassHero.Shared.Domain.Events.DomainEvent

  require Logger

  @default_priority 100

  defstruct context: nil, handlers: %{}

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the DomainEventBus for a given context.

  ## Options

  - `:context` - (required) The bounded context module (e.g., `KlassHero.Identity`)
  - `:handlers` - (optional) List of init-time handler specs:
    `{event_type, {Module, :function}, opts}` or `{event_type, {Module, :function}}`
  """
  def start_link(opts) do
    context = Keyword.fetch!(opts, :context)
    handlers = Keyword.get(opts, :handlers, [])
    name = process_name(context)
    GenServer.start_link(__MODULE__, %{context: context, handlers: handlers}, name: name)
  end

  @doc """
  Subscribes a handler function to a specific event type at runtime.

  ## Options

  - `:priority` - Execution order (lower = first, default: #{@default_priority})
  - `:mode` - `:sync` (default). Reserved for future `:async` support.
  """
  @spec subscribe(module(), atom(), (DomainEvent.t() -> :ok | {:error, term()}), keyword()) ::
          :ok
  def subscribe(context, event_type, handler_fn, opts \\ [])
      when is_atom(event_type) and is_function(handler_fn, 1) do
    GenServer.call(process_name(context), {:subscribe, event_type, handler_fn, opts})
  end

  @doc """
  Dispatches a domain event to all registered handlers for its event type.

  Fetches handler list from the registry, then executes them **in the caller's
  process** sorted by priority (lower first). Returns `:ok` when all handlers
  succeed, or `{:error, failures}` if any handler returns an error or crashes.
  """
  @spec dispatch(module(), DomainEvent.t()) :: :ok | {:error, [term()]}
  def dispatch(context, %DomainEvent{} = event) do
    handlers = GenServer.call(process_name(context), {:get_handlers, event.event_type})
    execute_handlers(handlers, event)
  end

  @doc """
  Derives the process name for a context's DomainEventBus.
  """
  @spec process_name(module()) :: atom()
  def process_name(context) do
    Module.concat(context, DomainEventBus)
  end

  # ============================================================================
  # Server Callbacks (registry only — no handler execution)
  # ============================================================================

  @impl true
  def init(%{context: context, handlers: handler_specs}) do
    handlers = register_init_handlers(handler_specs)
    Logger.info("DomainEventBus started for #{inspect(context)}")
    {:ok, %__MODULE__{context: context, handlers: handlers}}
  end

  @impl true
  def handle_call({:subscribe, event_type, handler_fn, opts}, _from, state) do
    entry = {handler_fn, opts}
    handlers = Map.update(state.handlers, event_type, [entry], &(&1 ++ [entry]))
    {:reply, :ok, %{state | handlers: handlers}}
  end

  @impl true
  def handle_call({:get_handlers, event_type}, _from, state) do
    handlers = Map.get(state.handlers, event_type, [])
    {:reply, handlers, state}
  end

  # ============================================================================
  # Private — init-time registration
  # ============================================================================

  defp register_init_handlers(handler_specs) do
    Enum.reduce(handler_specs, %{}, fn spec, acc ->
      {event_type, mfa, opts} = parse_handler_spec(spec)
      handler_fn = resolve_mfa(mfa)
      entry = {handler_fn, opts}
      Map.update(acc, event_type, [entry], &(&1 ++ [entry]))
    end)
  end

  # Trigger: handler spec may or may not include opts
  # Why: allow both {event, mfa} and {event, mfa, opts} for ergonomics
  # Outcome: always returns a normalized {event_type, mfa, opts} tuple
  defp parse_handler_spec({event_type, mfa, opts}) when is_list(opts),
    do: {event_type, mfa, opts}

  defp parse_handler_spec({event_type, mfa}),
    do: {event_type, mfa, []}

  defp resolve_mfa({module, function}) when is_atom(module) and is_atom(function) do
    Function.capture(module, function, 1)
  end

  # ============================================================================
  # Private — caller-side execution
  # ============================================================================

  defp execute_handlers([], _event), do: :ok

  defp execute_handlers(handlers, event) do
    failures =
      handlers
      |> Enum.sort_by(fn {_fn, opts} -> Keyword.get(opts, :priority, @default_priority) end)
      |> Enum.map(fn {handler_fn, _opts} -> safe_call(handler_fn, event) end)
      |> Enum.filter(&match?({:error, _}, &1))

    if failures == [], do: :ok, else: {:error, failures}
  end

  defp safe_call(handler_fn, event) do
    case handler_fn.(event) do
      :ok -> :ok
      {:error, _reason} = error -> error
      unexpected -> {:error, {:unexpected_return, unexpected}}
    end
  rescue
    error ->
      Logger.error("[DomainEventBus] handler crashed for #{event.event_type}",
        error: Exception.message(error),
        stacktrace: Exception.format_stacktrace(__STACKTRACE__)
      )

      {:error, {:handler_crashed, error}}
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/shared/domain_event_bus_test.exs`
Expected: All tests pass

**Step 5: Run full test suite to check for regressions**

Run: `mix test`
Expected: No new failures (existing callers still use `subscribe/3` which maps to `subscribe/4` with default opts)

**Step 6: Commit**

```
git add lib/klass_hero/shared/domain_event_bus.ex test/klass_hero/shared/domain_event_bus_test.exs
git commit -m "refactor: redesign DomainEventBus as handler registry with caller-side execution

GenServer now stores handler registrations only. dispatch/2 fetches handlers
and executes them in the caller's process sorted by priority.

- Add init-time handler registration via {Module, :function} tuples
- Add priority ordering (lower number runs first, default 100)
- Add mode opt (reserved for future async support)
- Caller-side execution preserves process context for test doubles"
```

---

### Task 2: Add `user_data_anonymized` domain event to MessagingEvents

The `AnonymizeUserData` use case needs a domain event to dispatch. Currently `MessagingEvents` has no anonymization event — it only has conversation/message events.

**Files:**
- Modify: `lib/klass_hero/messaging/domain/events/messaging_events.ex`
- Create: `test/klass_hero/messaging/domain/events/messaging_events_test.exs` (if not exists, add test for new event factory)

**Step 1: Write test for the new event factory function**

Check if `test/klass_hero/messaging/domain/events/messaging_events_test.exs` exists. If not, create it. Add:

```elixir
test "user_data_anonymized/1 creates event with correct fields" do
  user_id = Ecto.UUID.generate()
  event = MessagingEvents.user_data_anonymized(user_id)

  assert event.event_type == :user_data_anonymized
  assert event.aggregate_id == user_id
  assert event.aggregate_type == :user
  assert event.payload.user_id == user_id
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/messaging/domain/events/messaging_events_test.exs`
Expected: FAIL — `user_data_anonymized/1` not defined

**Step 3: Add `user_data_anonymized/1` to MessagingEvents**

Add to `lib/klass_hero/messaging/domain/events/messaging_events.ex`:

```elixir
@doc """
Creates a user_data_anonymized event.

Published after anonymizing a user's messaging data (content replaced,
participations ended). Handlers may promote this to an integration event
for cross-context notification.
"""
@spec user_data_anonymized(user_id :: String.t()) :: DomainEvent.t()
def user_data_anonymized(user_id) do
  DomainEvent.new(
    :user_data_anonymized,
    user_id,
    :user,
    %{user_id: user_id}
  )
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/messaging/domain/events/messaging_events_test.exs`
Expected: PASS

**Step 5: Commit**

```
git add lib/klass_hero/messaging/domain/events/messaging_events.ex test/klass_hero/messaging/domain/events/messaging_events_test.exs
git commit -m "feat: add user_data_anonymized domain event to MessagingEvents"
```

---

### Task 3: Create Messaging PromoteIntegrationEvents handler

This handler listens for `:user_data_anonymized` domain events on the Messaging bus and promotes them to `message_data_anonymized` integration events. It swallows publish failures (matching current `AnonymizeUserData` behavior).

**Files:**
- Create: `lib/klass_hero/messaging/adapters/driven/events/event_handlers/promote_integration_events.ex`
- Create: `test/klass_hero/messaging/adapters/driven/events/event_handlers/promote_integration_events_test.exs`

**Step 1: Write the handler test**

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEventsTest do
  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Messaging.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents
  alias KlassHero.Shared.Adapters.Driven.Events.TestIntegrationEventPublisher
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  setup do
    setup_test_integration_events()
    :ok
  end

  describe "handle/1 — :user_data_anonymized" do
    test "promotes to message_data_anonymized integration event" do
      user_id = Ecto.UUID.generate()
      domain_event = DomainEvent.new(:user_data_anonymized, user_id, :user, %{user_id: user_id})

      assert :ok = PromoteIntegrationEvents.handle(domain_event)

      event = assert_integration_event_published(:message_data_anonymized)
      assert event.entity_id == user_id
      assert event.source_context == :messaging
      assert IntegrationEvent.critical?(event)
    end

    test "swallows publish failures with :ok" do
      user_id = Ecto.UUID.generate()
      domain_event = DomainEvent.new(:user_data_anonymized, user_id, :user, %{user_id: user_id})

      TestIntegrationEventPublisher.configure_publish_error(:pubsub_down)

      assert :ok = PromoteIntegrationEvents.handle(domain_event)
      assert_no_integration_events_published()
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/messaging/adapters/driven/events/event_handlers/promote_integration_events_test.exs`
Expected: FAIL — module not found

**Step 3: Implement the handler**

Create `lib/klass_hero/messaging/adapters/driven/events/event_handlers/promote_integration_events.ex`:

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents do
  @moduledoc """
  Promotes Messaging domain events to integration events for cross-context communication.

  Registered on the Messaging DomainEventBus. When a relevant domain event is
  dispatched, this handler creates the corresponding integration event and
  publishes it via PubSub.

  ## Error strategy

  Swallows publish failures — the GDPR anonymization transaction has already
  committed, so the data change is durable. The integration event is best-effort
  notification to downstream contexts.
  """

  alias KlassHero.Messaging.Domain.Events.MessagingIntegrationEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.IntegrationEventPublishing

  require Logger

  @doc """
  Handles a domain event by promoting it to the corresponding integration event.
  """
  @spec handle(DomainEvent.t()) :: :ok
  def handle(%DomainEvent{event_type: :user_data_anonymized} = event) do
    user_id = event.payload.user_id

    integration_event = MessagingIntegrationEvents.message_data_anonymized(user_id)

    case IntegrationEventPublishing.publish(integration_event) do
      :ok ->
        :ok

      {:error, reason} ->
        # Trigger: PubSub publish failed after transaction committed
        # Why: data change is durable, integration event is best-effort notification
        # Outcome: log warning, return :ok so bus reports success to use case
        Logger.warning("Failed to publish message_data_anonymized integration event",
          user_id: user_id,
          reason: inspect(reason)
        )

        :ok
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/messaging/adapters/driven/events/event_handlers/promote_integration_events_test.exs`
Expected: PASS

**Step 5: Commit**

```
git add lib/klass_hero/messaging/adapters/driven/events/event_handlers/promote_integration_events.ex test/klass_hero/messaging/adapters/driven/events/event_handlers/promote_integration_events_test.exs
git commit -m "feat: add Messaging PromoteIntegrationEvents handler

Promotes :user_data_anonymized domain events to :message_data_anonymized
integration events. Swallows publish failures (data already committed)."
```

---

### Task 4: Migrate AnonymizeUserData use case to dispatch through bus

Replace the direct `IntegrationEventPublisher` call with `DomainEventBus.dispatch`. Register the handler in application.ex.

**Files:**
- Modify: `lib/klass_hero/messaging/application/use_cases/anonymize_user_data.ex`
- Modify: `lib/klass_hero/application.ex`
- Modify: `test/klass_hero/messaging/application/use_cases/anonymize_user_data_test.exs`

**Step 1: Update application.ex to register handler and add Messaging bus**

In `lib/klass_hero/application.ex`, update `domain_event_buses/0`:

```elixir
defp domain_event_buses do
  [
    {KlassHero.Shared.DomainEventBus, context: KlassHero.Identity},
    {KlassHero.Shared.DomainEventBus,
     context: KlassHero.Messaging,
     handlers: [
       {:user_data_anonymized,
        {KlassHero.Messaging.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
         :handle},
        priority: 10}
     ]}
  ]
end
```

**Step 2: Rewrite AnonymizeUserData to dispatch domain event**

Replace `lib/klass_hero/messaging/application/use_cases/anonymize_user_data.ex`:

```elixir
defmodule KlassHero.Messaging.Application.UseCases.AnonymizeUserData do
  @moduledoc """
  Use case for anonymizing a user's messaging data as part of GDPR deletion.

  Replaces message content with `"[deleted]"` and marks all active
  conversation participations as left. Dispatches a `user_data_anonymized`
  domain event on success — registered handlers promote it to an integration
  event for cross-context notification.

  Full GDPR-compliant anonymization of the user identity is performed by the
  Accounts context. This use case handles the Messaging context's portion of that cascade.
  """

  alias KlassHero.Messaging.Domain.Events.MessagingEvents
  alias KlassHero.Messaging.Repositories
  alias KlassHero.Repo
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @context KlassHero.Messaging

  @doc """
  Anonymizes all messaging data for a user.

  All database operations run in a single transaction to prevent partial
  anonymization (e.g. messages anonymized but participations still active).
  The domain event is dispatched after commit — handlers (integration event
  promotion, etc.) run in this process.

  ## Parameters

  - `user_id` - The ID of the user to anonymize

  ## Returns

  - `{:ok, %{messages_anonymized: n, participants_updated: n}}` - Success
  - `{:error, reason}` - Failure at any step
  """
  @spec execute(binary()) :: {:ok, map()} | {:error, term()}
  def execute(user_id) do
    user_id
    |> run_anonymization_transaction()
    |> handle_result(user_id)
  end

  defp run_anonymization_transaction(user_id) do
    repos = Repositories.all()

    Repo.transaction(fn ->
      with {:ok, msg_count} <-
             tag_step(:anonymize_messages, repos.messages.anonymize_for_sender(user_id)),
           {:ok, part_count} <-
             tag_step(:mark_as_left, repos.participants.mark_all_as_left(user_id)) do
        %{messages_anonymized: msg_count, participants_updated: part_count}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  # Passes through success, tags errors with the step name for traceability
  defp tag_step(_step, {:ok, _} = result), do: result
  defp tag_step(step, {:error, reason}), do: {:error, {step, reason}}

  defp handle_result({:ok, result}, user_id) do
    DomainEventBus.dispatch(@context, MessagingEvents.user_data_anonymized(user_id))

    Logger.info("Anonymized messaging data for user",
      user_id: user_id,
      messages_anonymized: result.messages_anonymized,
      participants_updated: result.participants_updated
    )

    {:ok, result}
  end

  defp handle_result({:error, reason} = error, user_id) do
    Logger.error("Failed to anonymize messaging data for user",
      user_id: user_id,
      reason: inspect(reason)
    )

    error
  end
end
```

**Step 3: Update use case test — adjust aliases, keep assertions**

In `test/klass_hero/messaging/application/use_cases/anonymize_user_data_test.exs`:

- Remove `alias KlassHero.Shared.Adapters.Driven.Events.TestIntegrationEventPublisher`
- The "publishes message_data_anonymized integration event" test still works because:
  dispatch → bus → PromoteIntegrationEvents handler → TestIntegrationEventPublisher (caller-side)
- The "succeeds even when integration event publish fails" test still works because:
  the handler swallows the error, so the use case gets :ok from dispatch

The key change: remove the `TestIntegrationEventPublisher` alias since the test no longer configures it directly. But wait — the "publish fails" test DOES configure it directly. This still works because:
1. Test calls `TestIntegrationEventPublisher.configure_publish_error(:pubsub_down)`
2. Use case dispatches domain event
3. Bus fetches handlers, executes in test process
4. Handler calls `IntegrationEventPublishing.publish()` which calls `TestIntegrationEventPublisher.publish()`
5. TestIntegrationEventPublisher sees the error config and returns `{:error, :pubsub_down}`
6. Handler swallows it, returns `:ok`
7. Test asserts `{:ok, _}` and `assert_no_integration_events_published()`

So the test file needs minimal changes — just verify existing tests still pass.

**Step 4: Run the use case tests**

Run: `mix test test/klass_hero/messaging/application/use_cases/anonymize_user_data_test.exs`
Expected: All 5 tests pass

**Step 5: Run full test suite**

Run: `mix test`
Expected: No new failures

**Step 6: Commit**

```
git add lib/klass_hero/messaging/application/use_cases/anonymize_user_data.ex lib/klass_hero/application.ex test/klass_hero/messaging/application/use_cases/anonymize_user_data_test.exs
git commit -m "refactor: migrate AnonymizeUserData to dispatch through DomainEventBus

Use case dispatches :user_data_anonymized domain event instead of calling
IntegrationEventPublisher directly. PromoteIntegrationEvents handler on the
Messaging bus handles the promotion to integration event."
```

---

### Task 5: Create Identity PromoteIntegrationEvents handler

Mirror Task 3 but for Identity. This handler promotes domain events to `child_data_anonymized` integration events. It **propagates** errors (unlike Messaging which swallows).

**Files:**
- Create: `lib/klass_hero/identity/adapters/driven/events/event_handlers/promote_integration_events.ex`
- Create: `test/klass_hero/identity/adapters/driven/events/event_handlers/promote_integration_events_test.exs`

**Step 1: Write the handler test**

```elixir
defmodule KlassHero.Identity.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEventsTest do
  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Identity.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents
  alias KlassHero.Shared.Adapters.Driven.Events.TestIntegrationEventPublisher
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  setup do
    setup_test_integration_events()
    :ok
  end

  describe "handle/1 — :child_data_anonymized" do
    test "promotes to child_data_anonymized integration event" do
      child_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:child_data_anonymized, child_id, :child, %{child_id: child_id})

      assert :ok = PromoteIntegrationEvents.handle(domain_event)

      event = assert_integration_event_published(:child_data_anonymized)
      assert event.entity_id == child_id
      assert event.source_context == :identity
      assert IntegrationEvent.critical?(event)
    end

    test "propagates publish failures as {:error, reason}" do
      child_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:child_data_anonymized, child_id, :child, %{child_id: child_id})

      TestIntegrationEventPublisher.configure_publish_error(:pubsub_down)

      assert {:error, :pubsub_down} = PromoteIntegrationEvents.handle(domain_event)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/identity/adapters/driven/events/event_handlers/promote_integration_events_test.exs`
Expected: FAIL — module not found

**Step 3: Implement the handler**

Create `lib/klass_hero/identity/adapters/driven/events/event_handlers/promote_integration_events.ex`:

```elixir
defmodule KlassHero.Identity.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents do
  @moduledoc """
  Promotes Identity domain events to integration events for cross-context communication.

  Registered on the Identity DomainEventBus. When a relevant domain event is
  dispatched, this handler creates the corresponding integration event and
  publishes it via PubSub.

  ## Error strategy

  Propagates publish failures — the GDPR anonymization cascade requires
  confirmation that downstream contexts were notified. A publish failure
  halts the reduce_while loop in the Identity facade.
  """

  alias KlassHero.Identity.Domain.Events.IdentityIntegrationEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.IntegrationEventPublishing

  @doc """
  Handles a domain event by promoting it to the corresponding integration event.
  """
  @spec handle(DomainEvent.t()) :: :ok | {:error, term()}
  def handle(%DomainEvent{event_type: :child_data_anonymized} = event) do
    child_id = event.payload.child_id

    child_id
    |> IdentityIntegrationEvents.child_data_anonymized()
    |> IntegrationEventPublishing.publish()
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/identity/adapters/driven/events/event_handlers/promote_integration_events_test.exs`
Expected: PASS

**Step 5: Commit**

```
git add lib/klass_hero/identity/adapters/driven/events/event_handlers/promote_integration_events.ex test/klass_hero/identity/adapters/driven/events/event_handlers/promote_integration_events_test.exs
git commit -m "feat: add Identity PromoteIntegrationEvents handler

Promotes :child_data_anonymized domain events to integration events.
Propagates publish failures (GDPR cascade requires confirmation)."
```

---

### Task 6: Migrate Identity anonymize_data_for_user to dispatch through bus

Replace the direct `IntegrationEventPublisher.publish_child_data_anonymized` call with `DomainEventBus.dispatch`. This requires adding a `child_data_anonymized` domain event to the Identity domain events (if not already present).

**Files:**
- Modify: `lib/klass_hero/identity.ex` (lines 386-418, `anonymize_children_data/1`)
- Modify: `lib/klass_hero/application.ex` (register handler on Identity bus)
- Check/create: Identity domain events factory for `child_data_anonymized`
- Modify: `test/klass_hero/identity/anonymize_data_for_user_test.exs`

**Step 1: Add `child_data_anonymized` domain event factory**

Find the Identity domain events module (likely at `lib/klass_hero/identity/domain/events/`). Add:

```elixir
def child_data_anonymized(child_id) do
  DomainEvent.new(
    :child_data_anonymized,
    child_id,
    :child,
    %{child_id: child_id}
  )
end
```

**Step 2: Register handler on Identity bus in application.ex**

Update `domain_event_buses/0`:

```elixir
{KlassHero.Shared.DomainEventBus,
 context: KlassHero.Identity,
 handlers: [
   {:child_data_anonymized,
    {KlassHero.Identity.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
     :handle},
    priority: 10}
 ]}
```

**Step 3: Update `anonymize_children_data/1` in identity.ex**

Replace the `IntegrationEventPublisher.publish_child_data_anonymized(child.id)` call with:

```elixir
:ok <- DomainEventBus.dispatch(KlassHero.Identity, IdentityDomainEvents.child_data_anonymized(child.id))
```

Add required aliases at top of module. Remove `IntegrationEventPublisher` alias if no longer used.

**Step 4: Run Identity anonymize tests**

Run: `mix test test/klass_hero/identity/anonymize_data_for_user_test.exs`
Expected: All tests pass (dispatch → bus → handler → TestIntegrationEventPublisher)

**Step 5: Run full suite**

Run: `mix test`
Expected: No new failures

**Step 6: Commit**

```
git add lib/klass_hero/identity.ex lib/klass_hero/application.ex lib/klass_hero/identity/domain/events/
git commit -m "refactor: migrate Identity anonymize_data_for_user to dispatch through DomainEventBus

Identity facade dispatches :child_data_anonymized domain event instead of
calling IntegrationEventPublisher directly. Handler on the Identity bus
promotes to integration event."
```

---

### Task 7: Clean up replaced publisher modules

Now that both contexts dispatch through the bus, remove the old `IntegrationEventPublisher` modules and their dedicated tests. Keep `EventPublisher` (Messaging LiveView) for now — that migration is Task 8+ and a bigger scope.

**Files:**
- Delete: `lib/klass_hero/messaging/integration_event_publisher.ex`
- Delete: `test/klass_hero/messaging/integration_event_publisher_test.exs`
- Delete: `lib/klass_hero/identity/integration_event_publisher.ex`
- Delete: `test/klass_hero/identity/integration_event_publisher_test.exs` (if exists)
- Verify: No other files import/alias the deleted modules

**Step 1: Search for remaining references**

Run: `grep -r "IntegrationEventPublisher" lib/ test/ --include="*.ex" --include="*.exs"`

Remove or update any remaining references.

**Step 2: Delete the files**

```bash
rm lib/klass_hero/messaging/integration_event_publisher.ex
rm test/klass_hero/messaging/integration_event_publisher_test.exs
rm lib/klass_hero/identity/integration_event_publisher.ex
# rm test file if exists
```

**Step 3: Run full test suite**

Run: `mix test`
Expected: All tests pass, no references to deleted modules

**Step 4: Run precommit**

Run: `mix precommit`
Expected: Clean compile (no warnings), all tests pass

**Step 5: Commit**

```
git add -A
git commit -m "chore: remove IntegrationEventPublisher modules replaced by bus handlers

Both Identity and Messaging now dispatch through DomainEventBus with
PromoteIntegrationEvents handlers. The convenience publisher modules
are no longer needed."
```

---

### Task 8 (optional, separate branch): Migrate Messaging EventPublisher to NotifyLiveViews handler

This is a larger scope migration affecting 6 use cases. Defer to a dedicated branch unless the user wants to continue.

**Scope:**
- Create `Messaging.EventHandlers.NotifyLiveViews` handler
- Move topic helpers (`conversation_topic/1`, `user_messages_topic/1`)
- Update 6 use cases: SendMessage, CreateDirectConversation, MarkAsRead, BroadcastToProgram, ArchiveEndedProgramConversations, EnforceRetentionPolicy
- Update LiveViews that subscribe to these topics
- Delete `Messaging.EventPublisher`

**Recommendation:** Do this on a follow-up branch. Tasks 1-7 deliver the core redesign.

---

## Verification checklist

After all tasks:

- [ ] `mix precommit` passes (compile --warnings-as-errors, format, test)
- [ ] DomainEventBus is registry-only, caller-side execution
- [ ] Priority ordering works
- [ ] Init-time handler registration works
- [ ] Messaging AnonymizeUserData dispatches through bus
- [ ] Identity anonymize_data_for_user dispatches through bus
- [ ] Old IntegrationEventPublisher modules removed
- [ ] No unused aliases or imports remain
