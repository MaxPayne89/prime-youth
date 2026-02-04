# Migrate All Contexts to DomainEventBus — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate Accounts, Participation, Community, Support to DomainEventBus dispatch. Delete all EventPublisher modules.

**Architecture:** Each context gets a DomainEventBus with registered handlers. Accounts promotes `user_registered` and `user_anonymized` to integration events. Participation/Community/Support use NotifyLiveViews handlers with derive_topic pattern for PubSub UI updates.

**Tech Stack:** Elixir, Phoenix PubSub, DomainEventBus (in-process sync handler registry)

**Note:** Messaging is already fully migrated — all 6 use cases use DomainEventBus.dispatch. Skipped.

---

## Task 1: Create AccountsIntegrationEvents factory module

**Files:**
- Create: `lib/klass_hero/accounts/domain/events/accounts_integration_events.ex`
- Test: `test/klass_hero/accounts/domain/events/accounts_integration_events_test.exs`

**Step 1: Write the test**

```elixir
# test/klass_hero/accounts/domain/events/accounts_integration_events_test.exs
defmodule KlassHero.Accounts.Domain.Events.AccountsIntegrationEventsTest do
  use ExUnit.Case, async: true

  alias KlassHero.Accounts.Domain.Events.AccountsIntegrationEvents
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  describe "user_registered/3" do
    test "creates a critical integration event with correct fields" do
      user_id = Ecto.UUID.generate()

      event = AccountsIntegrationEvents.user_registered(user_id, %{registration_source: :web})

      assert %IntegrationEvent{} = event
      assert event.event_type == :user_registered
      assert event.source_context == :accounts
      assert event.entity_type == :user
      assert event.entity_id == user_id
      assert event.payload.user_id == user_id
      assert event.payload.registration_source == :web
      assert IntegrationEvent.critical?(event)
    end

    test "raises on nil user_id" do
      assert_raise ArgumentError, fn ->
        AccountsIntegrationEvents.user_registered(nil)
      end
    end

    test "raises on empty user_id" do
      assert_raise ArgumentError, fn ->
        AccountsIntegrationEvents.user_registered("")
      end
    end
  end

  describe "user_anonymized/3" do
    test "creates a critical integration event with correct fields" do
      user_id = Ecto.UUID.generate()

      event = AccountsIntegrationEvents.user_anonymized(user_id, %{previous_email: "old@test.com"})

      assert %IntegrationEvent{} = event
      assert event.event_type == :user_anonymized
      assert event.source_context == :accounts
      assert event.entity_type == :user
      assert event.entity_id == user_id
      assert event.payload.user_id == user_id
      assert event.payload.previous_email == "old@test.com"
      assert IntegrationEvent.critical?(event)
    end

    test "raises on nil user_id" do
      assert_raise ArgumentError, fn ->
        AccountsIntegrationEvents.user_anonymized(nil)
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/accounts/domain/events/accounts_integration_events_test.exs`
Expected: Compilation error — module not found

**Step 3: Write the implementation**

```elixir
# lib/klass_hero/accounts/domain/events/accounts_integration_events.ex
defmodule KlassHero.Accounts.Domain.Events.AccountsIntegrationEvents do
  @moduledoc """
  Factory module for creating Accounts context integration events.

  Integration events are the public contract between bounded contexts.
  They carry stable, versioned payloads with only primitive types.

  ## Events

  - `:user_registered` - Emitted when a new user registers (critical).
    Downstream contexts (e.g. Identity) react to create profiles.

  - `:user_anonymized` - Emitted when a user is anonymized for GDPR (critical).
    Downstream contexts (e.g. Identity, Messaging) react to anonymize their data.
  """

  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  @source_context :accounts
  @entity_type :user

  @doc """
  Creates a `user_registered` integration event.

  Marked `:critical` by default — Identity depends on this to create profiles.
  """
  def user_registered(user_id, payload \\ %{}, opts \\ [])

  def user_registered(user_id, payload, opts)
      when is_binary(user_id) and byte_size(user_id) > 0 do
    base_payload = %{user_id: user_id}
    opts = Keyword.put_new(opts, :criticality, :critical)

    IntegrationEvent.new(
      :user_registered,
      @source_context,
      @entity_type,
      user_id,
      Map.merge(payload, base_payload),
      opts
    )
  end

  def user_registered(user_id, _payload, _opts) do
    raise ArgumentError,
          "user_registered/3 requires a non-empty user_id string, got: #{inspect(user_id)}"
  end

  @doc """
  Creates a `user_anonymized` integration event.

  Marked `:critical` by default — GDPR cascade must not be lost.
  """
  def user_anonymized(user_id, payload \\ %{}, opts \\ [])

  def user_anonymized(user_id, payload, opts)
      when is_binary(user_id) and byte_size(user_id) > 0 do
    base_payload = %{user_id: user_id}
    opts = Keyword.put_new(opts, :criticality, :critical)

    IntegrationEvent.new(
      :user_anonymized,
      @source_context,
      @entity_type,
      user_id,
      Map.merge(payload, base_payload),
      opts
    )
  end

  def user_anonymized(user_id, _payload, _opts) do
    raise ArgumentError,
          "user_anonymized/3 requires a non-empty user_id string, got: #{inspect(user_id)}"
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/accounts/domain/events/accounts_integration_events_test.exs`
Expected: All pass

**Step 5: Commit**

```
feat: add AccountsIntegrationEvents factory module
```

---

## Task 2: Create Accounts PromoteIntegrationEvents handler

**Files:**
- Create: `lib/klass_hero/accounts/adapters/driven/events/event_handlers/promote_integration_events.ex`
- Test: `test/klass_hero/accounts/adapters/driven/events/event_handlers/promote_integration_events_test.exs`

**Step 1: Write the test**

Pattern reference: `test/klass_hero/identity/adapters/driven/events/event_handlers/promote_integration_events_test.exs`

```elixir
# test/klass_hero/accounts/adapters/driven/events/event_handlers/promote_integration_events_test.exs
defmodule KlassHero.Accounts.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEventsTest do
  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Accounts.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents
  alias KlassHero.Shared.Adapters.Driven.Events.TestIntegrationEventPublisher
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  setup do
    setup_test_integration_events()
    :ok
  end

  describe "handle/1 — :user_registered" do
    test "promotes to user_registered integration event" do
      user_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:user_registered, user_id, :user, %{
          email: "test@example.com",
          name: "Test User",
          intended_roles: ["parent"]
        })

      assert :ok = PromoteIntegrationEvents.handle(domain_event)

      event = assert_integration_event_published(:user_registered)
      assert event.entity_id == user_id
      assert event.source_context == :accounts
      assert event.payload.user_id == user_id
      assert IntegrationEvent.critical?(event)
    end

    test "propagates publish failures" do
      user_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:user_registered, user_id, :user, %{
          email: "test@example.com",
          name: "Test User",
          intended_roles: ["parent"]
        })

      TestIntegrationEventPublisher.configure_publish_error(:pubsub_down)

      assert {:error, :pubsub_down} = PromoteIntegrationEvents.handle(domain_event)
    end
  end

  describe "handle/1 — :user_anonymized" do
    test "promotes to user_anonymized integration event" do
      user_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:user_anonymized, user_id, :user, %{
          anonymized_email: "deleted_#{user_id}@anonymized.local",
          previous_email: "old@example.com",
          anonymized_at: DateTime.utc_now()
        })

      assert :ok = PromoteIntegrationEvents.handle(domain_event)

      event = assert_integration_event_published(:user_anonymized)
      assert event.entity_id == user_id
      assert event.source_context == :accounts
      assert event.payload.user_id == user_id
      assert IntegrationEvent.critical?(event)
    end

    test "propagates publish failures" do
      user_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:user_anonymized, user_id, :user, %{
          anonymized_email: "deleted_#{user_id}@anonymized.local",
          previous_email: "old@example.com",
          anonymized_at: DateTime.utc_now()
        })

      TestIntegrationEventPublisher.configure_publish_error(:pubsub_down)

      assert {:error, :pubsub_down} = PromoteIntegrationEvents.handle(domain_event)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/accounts/adapters/driven/events/event_handlers/promote_integration_events_test.exs`
Expected: Compilation error — module not found

**Step 3: Write the implementation**

```elixir
# lib/klass_hero/accounts/adapters/driven/events/event_handlers/promote_integration_events.ex
defmodule KlassHero.Accounts.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents do
  @moduledoc """
  Promotes Accounts domain events to integration events for cross-context communication.

  Registered on the Accounts DomainEventBus. When a relevant domain event is
  dispatched, this handler creates the corresponding integration event and
  publishes it via PubSub.

  ## Error strategy

  Propagates publish failures — Identity profile creation depends on user_registered,
  and the GDPR anonymization cascade depends on user_anonymized.
  """

  alias KlassHero.Accounts.Domain.Events.AccountsIntegrationEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.IntegrationEventPublishing

  @spec handle(DomainEvent.t()) :: :ok | {:error, term()}
  def handle(%DomainEvent{event_type: :user_registered} = event) do
    # Trigger: user_registered domain event dispatched from accounts.ex
    # Why: Identity context needs this to auto-create parent/provider profiles
    # Outcome: publish integration event; propagate failure so caller knows
    event.aggregate_id
    |> AccountsIntegrationEvents.user_registered(event.payload)
    |> IntegrationEventPublishing.publish()
  end

  def handle(%DomainEvent{event_type: :user_anonymized} = event) do
    # Trigger: user_anonymized domain event dispatched from accounts.ex
    # Why: Identity and Messaging must anonymize their own data (GDPR cascade)
    # Outcome: publish integration event; propagate failure to halt cascade on error
    event.aggregate_id
    |> AccountsIntegrationEvents.user_anonymized(event.payload)
    |> IntegrationEventPublishing.publish()
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/accounts/adapters/driven/events/event_handlers/promote_integration_events_test.exs`
Expected: All pass

**Step 5: Commit**

```
feat: add Accounts PromoteIntegrationEvents handler
```

---

## Task 3: Migrate accounts.ex to DomainEventBus dispatch

**Files:**
- Modify: `lib/klass_hero/accounts.ex`

**Step 1: Replace EventPublisher calls with DomainEventBus.dispatch**

In `lib/klass_hero/accounts.ex`:

1. Replace the alias on line 8:
   - Remove `EventPublisher` from: `alias KlassHero.Accounts.{EventPublisher, User, UserNotifier, UserToken}`
   - Add: `alias KlassHero.Accounts.Domain.Events.UserEvents`
   - Add: `alias KlassHero.Shared.DomainEventBus`

2. In `register_user/1` (line 82), replace:
   ```elixir
   EventPublisher.publish_user_registered(user, registration_source: :web)
   ```
   with:
   ```elixir
   DomainEventBus.dispatch(
     KlassHero.Accounts,
     UserEvents.user_registered(user, %{registration_source: :web})
   )
   ```

3. In `update_user_email/2` (lines 161-163), replace the Multi step:
   ```elixir
   |> Ecto.Multi.run(:publish_event, fn _repo, %{update_email: updated_user} ->
     EventPublisher.publish_user_email_changed(updated_user, previous_email: previous_email)
     {:ok, updated_user}
   end)
   ```
   with:
   ```elixir
   |> Ecto.Multi.run(:publish_event, fn _repo, %{update_email: updated_user} ->
     DomainEventBus.dispatch(
       KlassHero.Accounts,
       UserEvents.user_email_changed(updated_user, %{previous_email: previous_email})
     )
     {:ok, updated_user}
   end)
   ```

4. In `login_user_by_magic_link/1` (lines 334-335), replace:
   ```elixir
   EventPublisher.publish_user_confirmed(confirmed_user,
     confirmation_method: :magic_link
   )
   ```
   with:
   ```elixir
   DomainEventBus.dispatch(
     KlassHero.Accounts,
     UserEvents.user_confirmed(confirmed_user, %{confirmation_method: :magic_link})
   )
   ```

5. In `anonymize_user/1` (lines 461-463), replace the Multi step:
   ```elixir
   |> Ecto.Multi.run(:publish_event, fn _repo, %{anonymize_user: anonymized_user} ->
     EventPublisher.publish_user_anonymized(anonymized_user, previous_email: previous_email)
     {:ok, anonymized_user}
   end)
   ```
   with:
   ```elixir
   |> Ecto.Multi.run(:publish_event, fn _repo, %{anonymize_user: anonymized_user} ->
     DomainEventBus.dispatch(
       KlassHero.Accounts,
       UserEvents.user_anonymized(anonymized_user, %{previous_email: previous_email})
     )
     {:ok, anonymized_user}
   end)
   ```

**Step 2: Run existing tests**

Run: `mix test test/klass_hero/accounts`
Expected: All pass (DomainEventBus not yet registered, but dispatch with no handlers returns :ok)

**Step 3: Commit**

```
refactor: migrate Accounts to dispatch through DomainEventBus
```

---

## Task 4: Register Accounts bus + update event subscribers in application.ex

**Files:**
- Modify: `lib/klass_hero/application.ex`

**Step 1: Add Accounts bus to `domain_event_buses/0`**

Add a new `Supervisor.child_spec` block at the beginning of the list in `domain_event_buses/0`:

```elixir
Supervisor.child_spec(
  {KlassHero.Shared.DomainEventBus,
   context: KlassHero.Accounts,
   handlers: [
     {:user_registered,
      {KlassHero.Accounts.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
       :handle}, priority: 10},
     {:user_anonymized,
      {KlassHero.Accounts.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
       :handle}, priority: 10}
   ]},
  id: :accounts_domain_event_bus
),
```

**Step 2: Move Identity and Messaging subscribers to integration_event_subscribers**

Replace the entire `event_subscribers/0` function with:

```elixir
defp event_subscribers, do: []
```

In `integration_event_subscribers/0`, add Identity and Messaging subscribers that listen to integration events from Accounts instead of domain events:

```elixir
defp integration_event_subscribers do
  [
    # Identity listens to Accounts integration events (user_registered, user_anonymized)
    Supervisor.child_spec(
      {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
       handler: KlassHero.Identity.Adapters.Driven.Events.IdentityEventHandler,
       topics: [
         "integration:accounts:user_registered",
         "integration:accounts:user_anonymized"
       ],
       message_tag: :integration_event,
       event_label: "Integration event"},
      id: :identity_integration_event_subscriber
    ),
    # Messaging listens to Accounts integration events (user_anonymized only)
    Supervisor.child_spec(
      {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
       handler: KlassHero.Messaging.Adapters.Driven.Events.MessagingEventHandler,
       topics: ["integration:accounts:user_anonymized"],
       message_tag: :integration_event,
       event_label: "Integration event"},
      id: :messaging_integration_event_subscriber
    ),
    # Participation listens to Identity integration events (child_data_anonymized)
    Supervisor.child_spec(
      {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
       handler: KlassHero.Participation.Adapters.Driven.Events.ParticipationEventHandler,
       topics: ["integration:identity:child_data_anonymized"],
       message_tag: :integration_event,
       event_label: "Integration event"},
      id: :participation_integration_event_subscriber
    )
  ]
end
```

Note: `user_confirmed` topic is dropped — IdentityEventHandler's catch-all ignores it.

**Step 3: Run full test suite**

Run: `mix test`
Expected: All pass

**Step 4: Commit**

```
refactor: register Accounts bus, move subscribers to integration events
```

---

## Task 5: Update IdentityEventHandler and MessagingEventHandler for entity_id

**Files:**
- Modify: `lib/klass_hero/identity/adapters/driven/events/identity_event_handler.ex`
- Modify: `lib/klass_hero/messaging/adapters/driven/events/messaging_event_handler.ex`

**Step 1: Update IdentityEventHandler**

In `lib/klass_hero/identity/adapters/driven/events/identity_event_handler.ex`:

Line 37 — change:
```elixir
def handle_event(%{event_type: :user_anonymized, aggregate_id: user_id}) do
```
to:
```elixir
def handle_event(%{event_type: :user_anonymized, entity_id: user_id}) do
```

Line 42 — change:
```elixir
def handle_event(%{event_type: :user_registered, aggregate_id: user_id, payload: payload}) do
```
to:
```elixir
def handle_event(%{event_type: :user_registered, entity_id: user_id, payload: payload}) do
```

**Step 2: Update MessagingEventHandler**

In `lib/klass_hero/messaging/adapters/driven/events/messaging_event_handler.ex`:

Line 29 — change:
```elixir
def handle_event(%{event_type: :user_anonymized, aggregate_id: user_id}) do
```
to:
```elixir
def handle_event(%{event_type: :user_anonymized, entity_id: user_id}) do
```

**Step 3: Run tests for both handlers**

Run: `mix test test/klass_hero/identity/adapters/driven/events/ test/klass_hero/messaging/adapters/driven/events/`
Expected: All pass

**Step 4: Commit**

```
refactor: update event handlers to match on entity_id (integration events)
```

---

## Task 6: Delete Accounts EventPublisher

**Files:**
- Delete: `lib/klass_hero/accounts/event_publisher.ex`
- Delete: `test/klass_hero/accounts/event_publisher_test.exs`

**Step 1: Delete files**

```bash
rm lib/klass_hero/accounts/event_publisher.ex
rm test/klass_hero/accounts/event_publisher_test.exs
```

**Step 2: Run compile + tests**

Run: `mix compile --warnings-as-errors && mix test`
Expected: Clean compile, all tests pass

**Step 3: Commit**

```
chore: delete Accounts.EventPublisher
```

---

## Task 7: Make Messaging NotifyLiveViews topic helpers public

**Files:**
- Modify: `lib/klass_hero/messaging/adapters/driven/events/event_handlers/notify_live_views.ex`
- Modify: `lib/klass_hero/messaging.ex` (if topic delegation exists there)

The topic helpers `conversation_topic/1` and `user_messages_topic/1` are currently private (line 97-98). They need to be public so `MessagingLiveHelper` can reference them via the `Messaging` facade.

**Step 1: Check how Messaging facade exposes topics**

Read `lib/klass_hero/messaging.ex` for `conversation_topic` and `user_messages_topic` — `MessagingLiveHelper` already calls `Messaging.conversation_topic/1` and `Messaging.user_messages_topic/1` (lines 233, 238). So the Messaging facade already delegates these. Verify those delegates point to somewhere valid.

If the facade delegates to EventPublisher (which is deleted for Messaging), update the delegation target to NotifyLiveViews instead.

**Step 2: Make helpers public on NotifyLiveViews**

In `lib/klass_hero/messaging/adapters/driven/events/event_handlers/notify_live_views.ex`:

Change lines 97-98 from:
```elixir
defp conversation_topic(conversation_id), do: "conversation:#{conversation_id}"
defp user_messages_topic(user_id), do: "user:#{user_id}:messages"
```
to:
```elixir
@doc "Returns PubSub topic for a specific conversation."
def conversation_topic(conversation_id), do: "conversation:#{conversation_id}"

@doc "Returns PubSub topic for a user's message updates."
def user_messages_topic(user_id), do: "user:#{user_id}:messages"
```

**Step 3: Update Messaging facade delegation if needed**

If `Messaging.conversation_topic/1` delegates to a now-deleted EventPublisher, update it to delegate to `NotifyLiveViews.conversation_topic/1`.

**Step 4: Run tests**

Run: `mix test test/klass_hero/messaging/ test/klass_hero_web/live/`
Expected: All pass

**Step 5: Commit**

```
refactor: make Messaging NotifyLiveViews topic helpers public
```

---

## Task 8: Create Participation NotifyLiveViews handler

**Files:**
- Create: `lib/klass_hero/participation/adapters/driven/events/event_handlers/notify_live_views.ex`
- Test: `test/klass_hero/participation/adapters/driven/events/event_handlers/notify_live_views_test.exs`

**Step 1: Write the test**

```elixir
# test/klass_hero/participation/adapters/driven/events/event_handlers/notify_live_views_test.exs
defmodule KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViewsTest do
  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews
  alias KlassHero.Shared.Domain.Events.DomainEvent

  setup do
    setup_test_events()
    :ok
  end

  describe "handle/1" do
    test "publishes session_created to derived topic" do
      session_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:session_created, session_id, :participation, %{
          session_id: session_id,
          program_id: Ecto.UUID.generate()
        })

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:session_created)
    end

    test "publishes child_checked_in to derived topic" do
      record_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:child_checked_in, record_id, :participation, %{
          record_id: record_id,
          session_id: Ecto.UUID.generate(),
          child_id: Ecto.UUID.generate()
        })

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:child_checked_in)
    end

    test "publishes behavioral_note_approved to derived topic" do
      note_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:behavioral_note_approved, note_id, :behavioral_note, %{
          note_id: note_id,
          status: :approved
        })

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:behavioral_note_approved)
    end
  end

  describe "derive_topic/1" do
    test "builds topic from aggregate_type and event_type" do
      event = DomainEvent.new(:session_created, "id", :participation, %{})
      assert NotifyLiveViews.derive_topic(event) == "participation:session_created"
    end
  end

  describe "build_topic/2" do
    test "builds topic string from atoms" do
      assert NotifyLiveViews.build_topic(:participation, :session_created) ==
               "participation:session_created"
    end
  end

  describe "error handling" do
    test "swallows publish failures and returns :ok" do
      event = DomainEvent.new(:session_started, "id", :participation, %{})
      assert :ok = NotifyLiveViews.handle(event)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/participation/adapters/driven/events/event_handlers/notify_live_views_test.exs`
Expected: Compilation error — module not found

**Step 3: Write the implementation**

```elixir
# lib/klass_hero/participation/adapters/driven/events/event_handlers/notify_live_views.ex
defmodule KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews do
  @moduledoc """
  Routes Participation domain events to PubSub topics for LiveView real-time updates.

  Uses derive_topic pattern: topic = "#{aggregate_type}:#{event_type}"

  ## Error strategy

  Swallows publish failures — the use case has already committed.
  PubSub delivery is best-effort notification to connected LiveViews.
  """

  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.EventPublishing

  require Logger

  @doc "Handles a domain event by publishing it to the derived PubSub topic."
  @spec handle(DomainEvent.t()) :: :ok
  def handle(%DomainEvent{} = event) do
    topic = derive_topic(event)
    safe_publish(event, topic)
  end

  @doc "Derives a PubSub topic from a domain event's aggregate_type and event_type."
  @spec derive_topic(DomainEvent.t()) :: String.t()
  def derive_topic(%DomainEvent{aggregate_type: agg, event_type: evt}) do
    build_topic(agg, evt)
  end

  @doc "Builds a PubSub topic string from aggregate type and event type atoms."
  @spec build_topic(atom(), atom()) :: String.t()
  def build_topic(aggregate_type, event_type) do
    "#{aggregate_type}:#{event_type}"
  end

  defp safe_publish(event, topic) do
    case EventPublishing.publisher_module().publish(event, topic) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to publish #{event.event_type} to #{topic}",
          event_type: event.event_type,
          topic: topic,
          reason: inspect(reason)
        )

        :ok
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/participation/adapters/driven/events/event_handlers/notify_live_views_test.exs`
Expected: All pass

**Step 5: Commit**

```
feat: add Participation NotifyLiveViews handler
```

---

## Task 9: Migrate Participation use cases to DomainEventBus + register bus

**Files:**
- Modify: `lib/klass_hero/participation/application/use_cases/create_session.ex`
- Modify: `lib/klass_hero/participation/application/use_cases/start_session.ex`
- Modify: `lib/klass_hero/participation/application/use_cases/complete_session.ex`
- Modify: `lib/klass_hero/participation/application/use_cases/record_check_in.ex`
- Modify: `lib/klass_hero/participation/application/use_cases/record_check_out.ex`
- Modify: `lib/klass_hero/participation/application/use_cases/bulk_check_in.ex`
- Modify: `lib/klass_hero/participation/application/use_cases/submit_behavioral_note.ex`
- Modify: `lib/klass_hero/participation/application/use_cases/review_behavioral_note.ex`
- Modify: `lib/klass_hero/participation/application/use_cases/revise_behavioral_note.ex`
- Modify: `lib/klass_hero/application.ex`

**Step 1: Mechanical replacement in all 9 use cases**

In each use case file, apply this pattern:

1. Remove: `alias KlassHero.Participation.EventPublisher`
2. Add: `alias KlassHero.Shared.DomainEventBus`
3. Add: `@context KlassHero.Participation`
4. In `publish_event` helpers, replace `EventPublisher.publish()` with `DomainEventBus.dispatch(@context, event)`:

Before (every use case):
```elixir
defp publish_event(entity) do
  entity
  |> ParticipationEvents.some_event()
  |> EventPublisher.publish()
end
```

After:
```elixir
defp publish_event(entity) do
  event = ParticipationEvents.some_event(entity)
  DomainEventBus.dispatch(@context, event)
end
```

For `complete_session.ex` which has two publish functions:
```elixir
defp publish_session_completed(session) do
  event = ParticipationEvents.session_completed(session)
  DomainEventBus.dispatch(@context, event)
end

defp publish_child_absent(record) do
  event = ParticipationEvents.child_marked_absent(record)
  DomainEventBus.dispatch(@context, event)
end
```

For `review_behavioral_note.ex` which has two clauses:
```elixir
defp publish_event(note, :approve) do
  event = ParticipationEvents.behavioral_note_approved(note)
  DomainEventBus.dispatch(@context, event)
end

defp publish_event(note, :reject) do
  event = ParticipationEvents.behavioral_note_rejected(note)
  DomainEventBus.dispatch(@context, event)
end
```

**Step 2: Register Participation bus in application.ex**

In `domain_event_buses/0`, add:

```elixir
Supervisor.child_spec(
  {KlassHero.Shared.DomainEventBus,
   context: KlassHero.Participation,
   handlers: [
     {:session_created,
      {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}},
     {:session_started,
      {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}},
     {:session_completed,
      {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}},
     {:child_checked_in,
      {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}},
     {:child_checked_out,
      {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}},
     {:child_marked_absent,
      {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}},
     {:behavioral_note_submitted,
      {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}},
     {:behavioral_note_approved,
      {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}},
     {:behavioral_note_rejected,
      {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}}
   ]},
  id: :participation_domain_event_bus
),
```

**Step 3: Run tests**

Run: `mix test test/klass_hero/participation/`
Expected: All pass

**Step 4: Commit**

```
refactor: migrate Participation use cases to dispatch through DomainEventBus
```

---

## Task 10: Delete Participation EventPublisher

**Files:**
- Delete: `lib/klass_hero/participation/event_publisher.ex`

**Step 1: Delete file**

```bash
rm lib/klass_hero/participation/event_publisher.ex
```

**Step 2: Run compile + tests**

Run: `mix compile --warnings-as-errors && mix test`
Expected: Clean compile, all tests pass

**Step 3: Commit**

```
chore: delete Participation.EventPublisher
```

---

## Task 11: Create Community NotifyLiveViews handler

**Files:**
- Create: `lib/klass_hero/community/adapters/driven/events/event_handlers/notify_live_views.ex`
- Test: `test/klass_hero/community/adapters/driven/events/event_handlers/notify_live_views_test.exs`

**Step 1: Write the test**

```elixir
# test/klass_hero/community/adapters/driven/events/event_handlers/notify_live_views_test.exs
defmodule KlassHero.Community.Adapters.Driven.Events.EventHandlers.NotifyLiveViewsTest do
  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Community.Adapters.Driven.Events.EventHandlers.NotifyLiveViews
  alias KlassHero.Shared.Domain.Events.DomainEvent

  setup do
    setup_test_events()
    :ok
  end

  describe "handle/1" do
    test "publishes comment_added to derived topic" do
      post_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:comment_added, post_id, :post, %{
          post_id: post_id,
          author: "John",
          comment_text: "Nice"
        })

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:comment_added)
    end

    test "publishes post_liked to derived topic" do
      post_id = Ecto.UUID.generate()

      event = DomainEvent.new(:post_liked, post_id, :post, %{post_id: post_id})

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:post_liked)
    end

    test "publishes post_unliked to derived topic" do
      post_id = Ecto.UUID.generate()

      event = DomainEvent.new(:post_unliked, post_id, :post, %{post_id: post_id})

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:post_unliked)
    end
  end

  describe "derive_topic/1" do
    test "builds topic from aggregate_type and event_type" do
      event = DomainEvent.new(:post_liked, "id", :post, %{})
      assert NotifyLiveViews.derive_topic(event) == "post:post_liked"
    end
  end

  describe "build_topic/2" do
    test "builds topic string from atoms" do
      assert NotifyLiveViews.build_topic(:post, :post_liked) == "post:post_liked"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/community/adapters/driven/events/event_handlers/notify_live_views_test.exs`
Expected: Compilation error — module not found

**Step 3: Write the implementation**

```elixir
# lib/klass_hero/community/adapters/driven/events/event_handlers/notify_live_views.ex
defmodule KlassHero.Community.Adapters.Driven.Events.EventHandlers.NotifyLiveViews do
  @moduledoc """
  Routes Community domain events to PubSub topics for LiveView real-time updates.

  Uses derive_topic pattern: topic = "#{aggregate_type}:#{event_type}"

  ## Error strategy

  Swallows publish failures — PubSub delivery is best-effort.
  """

  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.EventPublishing

  require Logger

  @spec handle(DomainEvent.t()) :: :ok
  def handle(%DomainEvent{} = event) do
    topic = derive_topic(event)
    safe_publish(event, topic)
  end

  @spec derive_topic(DomainEvent.t()) :: String.t()
  def derive_topic(%DomainEvent{aggregate_type: agg, event_type: evt}) do
    build_topic(agg, evt)
  end

  @spec build_topic(atom(), atom()) :: String.t()
  def build_topic(aggregate_type, event_type) do
    "#{aggregate_type}:#{event_type}"
  end

  defp safe_publish(event, topic) do
    case EventPublishing.publisher_module().publish(event, topic) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to publish #{event.event_type} to #{topic}",
          event_type: event.event_type,
          topic: topic,
          reason: inspect(reason)
        )

        :ok
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/community/adapters/driven/events/event_handlers/notify_live_views_test.exs`
Expected: All pass

**Step 5: Commit**

```
feat: add Community NotifyLiveViews handler
```

---

## Task 12: Migrate Community use cases + CommunityLive + register bus

**Files:**
- Modify: `lib/klass_hero/community/application/use_cases/add_comment.ex`
- Modify: `lib/klass_hero/community/application/use_cases/toggle_like.ex`
- Modify: `lib/klass_hero_web/live/community_live.ex`
- Modify: `lib/klass_hero/application.ex`

**Step 1: Migrate add_comment.ex**

1. Remove: `alias KlassHero.Community.EventPublisher`
2. Add: `alias KlassHero.Shared.DomainEventBus`
3. Add: `@context KlassHero.Community`
4. Replace line 76:
   ```elixir
   EventPublisher.publish_comment_added(updated_post, author, comment_text)
   ```
   with:
   ```elixir
   DomainEventBus.dispatch(
     @context,
     CommunityEvents.comment_added(updated_post, author, comment_text)
   )
   ```

**Step 2: Migrate toggle_like.ex**

1. Remove: `alias KlassHero.Community.EventPublisher`
2. Add: `alias KlassHero.Shared.DomainEventBus`
3. Add: `@context KlassHero.Community`
4. Replace publish_like_event helpers:
   ```elixir
   defp publish_like_event(%Post{user_liked: true} = post) do
     DomainEventBus.dispatch(@context, CommunityEvents.post_liked(post))
   end

   defp publish_like_event(%Post{user_liked: false} = post) do
     DomainEventBus.dispatch(@context, CommunityEvents.post_unliked(post))
   end
   ```

**Step 3: Update CommunityLive topic subscriptions**

In `lib/klass_hero_web/live/community_live.ex`:

1. Remove: `alias KlassHero.Shared.Adapters.Driven.Events.PubSubEventPublisher`
2. Add: `alias KlassHero.Community.Adapters.Driven.Events.EventHandlers.NotifyLiveViews`
3. Replace topic construction (lines 52-56):
   ```elixir
   defp subscribe_to_post_events do
     topics = [
       NotifyLiveViews.build_topic(:post, :post_liked),
       NotifyLiveViews.build_topic(:post, :post_unliked),
       NotifyLiveViews.build_topic(:post, :comment_added)
     ]

     Enum.each(topics, &Phoenix.PubSub.subscribe(KlassHero.PubSub, &1))
   end
   ```

**Step 4: Register Community bus in application.ex**

In `domain_event_buses/0`, add:

```elixir
Supervisor.child_spec(
  {KlassHero.Shared.DomainEventBus,
   context: KlassHero.Community,
   handlers: [
     {:comment_added,
      {KlassHero.Community.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}},
     {:post_liked,
      {KlassHero.Community.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}},
     {:post_unliked,
      {KlassHero.Community.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}}
   ]},
  id: :community_domain_event_bus
),
```

**Step 5: Run tests**

Run: `mix test test/klass_hero/community/ test/klass_hero_web/live/community_live_test.exs`
Expected: All pass

**Step 6: Commit**

```
refactor: migrate Community use cases + CommunityLive to DomainEventBus
```

---

## Task 13: Delete Community EventPublisher

**Files:**
- Delete: `lib/klass_hero/community/event_publisher.ex`

**Step 1: Delete file**

```bash
rm lib/klass_hero/community/event_publisher.ex
```

**Step 2: Run compile + tests**

Run: `mix compile --warnings-as-errors && mix test`
Expected: Clean compile, all tests pass

**Step 3: Commit**

```
chore: delete Community.EventPublisher
```

---

## Task 14: Create Support NotifyLiveViews handler

**Files:**
- Create: `lib/klass_hero/support/adapters/driven/events/event_handlers/notify_live_views.ex`
- Test: `test/klass_hero/support/adapters/driven/events/event_handlers/notify_live_views_test.exs`

**Step 1: Write the test**

```elixir
# test/klass_hero/support/adapters/driven/events/event_handlers/notify_live_views_test.exs
defmodule KlassHero.Support.Adapters.Driven.Events.EventHandlers.NotifyLiveViewsTest do
  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Support.Adapters.Driven.Events.EventHandlers.NotifyLiveViews
  alias KlassHero.Shared.Domain.Events.DomainEvent

  setup do
    setup_test_events()
    :ok
  end

  describe "handle/1" do
    test "publishes contact_request_submitted to derived topic" do
      request_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:contact_request_submitted, request_id, :contact_request, %{
          request_id: request_id,
          email: "help@example.com"
        })

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:contact_request_submitted)
    end
  end

  describe "derive_topic/1" do
    test "builds topic from aggregate_type and event_type" do
      event = DomainEvent.new(:contact_request_submitted, "id", :contact_request, %{})

      assert NotifyLiveViews.derive_topic(event) ==
               "contact_request:contact_request_submitted"
    end
  end

  describe "build_topic/2" do
    test "builds topic string" do
      assert NotifyLiveViews.build_topic(:contact_request, :contact_request_submitted) ==
               "contact_request:contact_request_submitted"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/support/adapters/driven/events/event_handlers/notify_live_views_test.exs`
Expected: Compilation error

**Step 3: Write the implementation**

```elixir
# lib/klass_hero/support/adapters/driven/events/event_handlers/notify_live_views.ex
defmodule KlassHero.Support.Adapters.Driven.Events.EventHandlers.NotifyLiveViews do
  @moduledoc """
  Routes Support domain events to PubSub topics for LiveView real-time updates.

  Uses derive_topic pattern: topic = "#{aggregate_type}:#{event_type}"

  ## Error strategy

  Swallows publish failures — PubSub delivery is best-effort.
  """

  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.EventPublishing

  require Logger

  @spec handle(DomainEvent.t()) :: :ok
  def handle(%DomainEvent{} = event) do
    topic = derive_topic(event)
    safe_publish(event, topic)
  end

  @spec derive_topic(DomainEvent.t()) :: String.t()
  def derive_topic(%DomainEvent{aggregate_type: agg, event_type: evt}) do
    build_topic(agg, evt)
  end

  @spec build_topic(atom(), atom()) :: String.t()
  def build_topic(aggregate_type, event_type) do
    "#{aggregate_type}:#{event_type}"
  end

  defp safe_publish(event, topic) do
    case EventPublishing.publisher_module().publish(event, topic) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to publish #{event.event_type} to #{topic}",
          event_type: event.event_type,
          topic: topic,
          reason: inspect(reason)
        )

        :ok
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/support/adapters/driven/events/event_handlers/notify_live_views_test.exs`
Expected: All pass

**Step 5: Commit**

```
feat: add Support NotifyLiveViews handler
```

---

## Task 15: Migrate Support use case + register bus + delete EventPublisher

**Files:**
- Modify: `lib/klass_hero/support/application/use_cases/submit_contact_form.ex`
- Modify: `lib/klass_hero/application.ex`
- Delete: `lib/klass_hero/support/event_publisher.ex`

**Step 1: Migrate submit_contact_form.ex**

1. Remove: `alias KlassHero.Support.EventPublisher`
2. Add: `alias KlassHero.Shared.DomainEventBus`
3. Add: `@context KlassHero.Support`
4. Replace line 114:
   ```elixir
   EventPublisher.publish_contact_request_submitted(submitted_request)
   ```
   with:
   ```elixir
   DomainEventBus.dispatch(
     @context,
     SupportEvents.contact_request_submitted(submitted_request)
   )
   ```

**Step 2: Register Support bus in application.ex**

In `domain_event_buses/0`, add:

```elixir
Supervisor.child_spec(
  {KlassHero.Shared.DomainEventBus,
   context: KlassHero.Support,
   handlers: [
     {:contact_request_submitted,
      {KlassHero.Support.Adapters.Driven.Events.EventHandlers.NotifyLiveViews, :handle}}
   ]},
  id: :support_domain_event_bus
),
```

**Step 3: Delete Support EventPublisher**

```bash
rm lib/klass_hero/support/event_publisher.ex
```

**Step 4: Run compile + tests**

Run: `mix compile --warnings-as-errors && mix test`
Expected: Clean compile, all tests pass

**Step 5: Commit**

```
refactor: migrate Support to DomainEventBus, delete EventPublisher
```

---

## Task 16: Final cleanup + remove event_subscribers/0

**Files:**
- Modify: `lib/klass_hero/application.ex`

**Step 1: Remove empty event_subscribers/0**

If `event_subscribers/0` returns `[]` (done in Task 4), remove the function entirely and remove it from the `domain_children/0` pipeline:

```elixir
defp domain_children do
  domain_event_buses() ++
    integration_event_subscribers() ++
    in_memory_repositories()
end
```

**Step 2: Verify no remaining EventPublisher references**

Run: `grep -r "EventPublisher" lib/ test/ --include="*.ex" --include="*.exs"`
Expected: No matches (or only in deleted test fixtures/mocks)

**Step 3: Verify no remaining PubSubEventPublisher.build_topic references in LiveViews**

Run: `grep -r "PubSubEventPublisher.build_topic" lib/klass_hero_web/`
Expected: No matches

**Step 4: Run full precommit**

Run: `mix precommit`
Expected: Clean compile (warnings-as-errors), format OK, all tests pass

**Step 5: Commit**

```
chore: remove event_subscribers/0, final cleanup
```

---

## Summary of all commits

1. `feat: add AccountsIntegrationEvents factory module`
2. `feat: add Accounts PromoteIntegrationEvents handler`
3. `refactor: migrate Accounts to dispatch through DomainEventBus`
4. `refactor: register Accounts bus, move subscribers to integration events`
5. `refactor: update event handlers to match on entity_id (integration events)`
6. `chore: delete Accounts.EventPublisher`
7. `refactor: make Messaging NotifyLiveViews topic helpers public`
8. `feat: add Participation NotifyLiveViews handler`
9. `refactor: migrate Participation use cases to dispatch through DomainEventBus`
10. `chore: delete Participation.EventPublisher`
11. `feat: add Community NotifyLiveViews handler`
12. `refactor: migrate Community use cases + CommunityLive to DomainEventBus`
13. `chore: delete Community.EventPublisher`
14. `feat: add Support NotifyLiveViews handler`
15. `refactor: migrate Support to DomainEventBus, delete EventPublisher`
16. `chore: remove event_subscribers/0, final cleanup`
