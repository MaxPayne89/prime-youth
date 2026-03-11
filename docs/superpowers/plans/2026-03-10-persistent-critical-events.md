# Persistent Critical Events Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure events marked `:critical` are never silently lost — domain events get Oban-backed retry on handler failure, integration events get dual delivery (PubSub + Oban).

**Architecture:** A `processed_events` table provides per-handler idempotency via composite `{event_id, handler_ref}` key. A `CriticalEventDispatcher` domain service owns the exactly-once invariant using transactional insert + handler execution. A generic `CriticalEventWorker` Oban worker retries failed handlers. Existing modules (`EventDispatchHelper`, `EventSubscriber`, `PubSubIntegrationEventPublisher`, `DomainEventBus`) are modified to route critical events through the new infrastructure.

**Tech Stack:** Elixir, Ecto (migrations, transactions), Oban (workers, queues), Phoenix.PubSub

**Spec:** `docs/superpowers/specs/2026-03-10-persistent-critical-events-design.md`

**Skills:** `@superpowers:test-driven-development`, `@idiomatic-elixir`

---

## File Structure

### New Files

| File | Responsibility |
|---|---|
| `priv/repo/migrations/TIMESTAMP_create_processed_events.exs` | Migration for idempotency table |
| `lib/klass_hero/shared/adapters/driven/persistence/schemas/processed_event.ex` | Ecto schema for `processed_events` |
| `lib/klass_hero/shared/domain/services/critical_event_dispatcher.ex` | Exactly-once dispatch: `execute/3`, `mark_processed/2`, `handler_ref/1` |
| `lib/klass_hero/shared/adapters/driven/events/critical_event_serializer.ex` | Event struct ↔ JSON round-trip |
| `lib/klass_hero/shared/adapters/driven/events/critical_event_handler_registry.ex` | Config-driven topic → handler lookup |
| `lib/klass_hero/shared/adapters/driven/workers/critical_event_worker.ex` | Generic Oban worker for critical event retry |
| `test/klass_hero/shared/domain/services/critical_event_dispatcher_test.exs` | Tests for dispatcher |
| `test/klass_hero/shared/adapters/driven/events/critical_event_serializer_test.exs` | Serialization round-trip tests |
| `test/klass_hero/shared/adapters/driven/events/critical_event_handler_registry_test.exs` | Registry lookup tests |
| `test/klass_hero/shared/adapters/driven/workers/critical_event_worker_test.exs` | Oban worker tests |

### Modified Files

| File | Change |
|---|---|
| `lib/klass_hero/shared/domain_event_bus.ex` | Add `dispatch_critical/2`, store handler identity alongside captured fns |
| `lib/klass_hero/shared/event_dispatch_helper.ex` | Route critical domain events through new infrastructure |
| `lib/klass_hero/shared/adapters/driven/events/event_subscriber.ex` | Wrap critical integration event handlers in `CriticalEventDispatcher` |
| `lib/klass_hero/shared/adapters/driven/events/pubsub_integration_event_publisher.ex` | Enqueue Oban jobs for critical integration events |
| `config/config.exs` | Add `:critical_events` Oban queue, add `:critical_event_handlers` config |
| `config/test.exs` | Add test config for `:critical_event_handlers` |
| `test/klass_hero/shared/domain_event_bus_test.exs` | Tests for `dispatch_critical/2` |
| `test/klass_hero/shared/event_dispatch_helper_test.exs` | Tests for critical event routing |
| `test/klass_hero/shared/adapters/driven/events/event_subscriber_integration_test.exs` | Tests for critical event wrapping |

---

## Chunk 1: Foundation (Table, Schema, Dispatcher)

### Task 1: Migration and Schema

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_processed_events.exs`
- Create: `lib/klass_hero/shared/adapters/driven/persistence/schemas/processed_event.ex`

- [ ] **Step 1: Write the migration**

```bash
mix ecto.gen.migration create_processed_events
```

Then edit the generated file:

```elixir
defmodule KlassHero.Repo.Migrations.CreateProcessedEvents do
  use Ecto.Migration

  def change do
    create table(:processed_events, primary_key: false) do
      add :event_id, :uuid, null: false
      add :handler_ref, :string, null: false
      add :processed_at, :utc_datetime_usec, null: false
    end

    # Composite unique constraint for idempotency: one row per event-handler pair
    create unique_index(:processed_events, [:event_id, :handler_ref])
  end
end
```

- [ ] **Step 2: Run the migration**

```bash
mix ecto.migrate
```

Expected: Migration runs successfully, table created.

- [ ] **Step 3: Write the Ecto schema**

Create `lib/klass_hero/shared/adapters/driven/persistence/schemas/processed_event.ex`:

```elixir
defmodule KlassHero.Shared.Adapters.Driven.Persistence.Schemas.ProcessedEvent do
  @moduledoc """
  Ecto schema for the processed_events idempotency table.

  Internal to CriticalEventDispatcher — not a domain model. Each row records
  that a specific handler has processed a specific event, preventing duplicate
  execution across PubSub and Oban delivery paths.
  """

  use Ecto.Schema

  @primary_key false
  schema "processed_events" do
    field :event_id, Ecto.UUID
    field :handler_ref, :string
    field :processed_at, :utc_datetime_usec
  end
end
```

- [ ] **Step 4: Verify compilation**

```bash
mix compile --warnings-as-errors
```

Expected: Compiles cleanly.

- [ ] **Step 5: Commit**

```bash
git add priv/repo/migrations/*_create_processed_events.exs lib/klass_hero/shared/adapters/driven/persistence/schemas/processed_event.ex
git commit -m "Add processed_events table and schema for critical event idempotency (#325)"
```

---

### Task 2: CriticalEventDispatcher — `handler_ref/1`

**Files:**
- Create: `test/klass_hero/shared/domain/services/critical_event_dispatcher_test.exs`
- Create: `lib/klass_hero/shared/domain/services/critical_event_dispatcher.ex`

- [ ] **Step 1: Write the failing test for `handler_ref/1`**

Create `test/klass_hero/shared/domain/services/critical_event_dispatcher_test.exs`:

```elixir
defmodule KlassHero.Shared.Domain.Services.CriticalEventDispatcherTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Shared.Domain.Services.CriticalEventDispatcher

  describe "handler_ref/1" do
    test "produces canonical string from {module, function} tuple" do
      ref = CriticalEventDispatcher.handler_ref({MyApp.SomeHandler, :handle_event})
      assert ref == "Elixir.MyApp.SomeHandler:handle_event"
    end

    test "produces different refs for different functions on same module" do
      ref_a = CriticalEventDispatcher.handler_ref({MyApp.Handler, :handle})
      ref_b = CriticalEventDispatcher.handler_ref({MyApp.Handler, :handle_event})
      assert ref_a != ref_b
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/klass_hero/shared/domain/services/critical_event_dispatcher_test.exs --max-failures 1
```

Expected: FAIL — module `CriticalEventDispatcher` not found.

- [ ] **Step 3: Write minimal implementation**

Create `lib/klass_hero/shared/domain/services/critical_event_dispatcher.ex`:

```elixir
defmodule KlassHero.Shared.Domain.Services.CriticalEventDispatcher do
  @moduledoc """
  Exactly-once dispatch for critical events.

  Owns the idempotency invariant: a given event-handler pair is processed at
  most once, regardless of how many delivery paths attempt it. Both the PubSub
  real-time path and the Oban durable path funnel through this module.

  Uses a `processed_events` table with composite key `{event_id, handler_ref}`
  and transactional insert + handler execution to guarantee atomicity.
  """

  @doc """
  Derives the canonical handler reference string from a `{module, function}` tuple.

  Format: `"Elixir.Module.Name:function_name"`

  Used as the `handler_ref` column value in the `processed_events` table and in
  Oban job args. Both delivery paths must produce the same string for the same
  handler to ensure idempotency deduplication works.
  """
  @spec handler_ref({module(), atom()}) :: String.t()
  def handler_ref({module, function}) when is_atom(module) and is_atom(function) do
    "#{inspect(module)}:#{function}"
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
mix test test/klass_hero/shared/domain/services/critical_event_dispatcher_test.exs
```

Expected: 2 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add test/klass_hero/shared/domain/services/critical_event_dispatcher_test.exs lib/klass_hero/shared/domain/services/critical_event_dispatcher.ex
git commit -m "Add CriticalEventDispatcher with handler_ref/1 (#325)"
```

---

### Task 3: CriticalEventDispatcher — `execute/3`

**Files:**
- Modify: `test/klass_hero/shared/domain/services/critical_event_dispatcher_test.exs`
- Modify: `lib/klass_hero/shared/domain/services/critical_event_dispatcher.ex`

- [ ] **Step 1: Write failing tests for `execute/3`**

Add to the existing test file:

```elixir
  describe "execute/3" do
    test "runs handler and inserts processed_events row on success" do
      event_id = Ecto.UUID.generate()
      handler_ref = "Elixir.TestModule:handle"
      test_pid = self()

      result =
        CriticalEventDispatcher.execute(event_id, handler_ref, fn ->
          send(test_pid, :handler_called)
          :ok
        end)

      assert result == :ok
      assert_received :handler_called

      # Verify row exists
      assert Repo.get_by(ProcessedEvent, event_id: event_id, handler_ref: handler_ref)
    end

    test "skips handler and returns :ok when already processed" do
      event_id = Ecto.UUID.generate()
      handler_ref = "Elixir.TestModule:handle"
      test_pid = self()

      # First call processes normally
      :ok =
        CriticalEventDispatcher.execute(event_id, handler_ref, fn ->
          send(test_pid, :first_call)
          :ok
        end)

      assert_received :first_call

      # Second call is idempotent — handler not called
      :ok =
        CriticalEventDispatcher.execute(event_id, handler_ref, fn ->
          send(test_pid, :second_call)
          :ok
        end)

      refute_received :second_call
    end

    test "rolls back processed_events row on handler failure" do
      event_id = Ecto.UUID.generate()
      handler_ref = "Elixir.TestModule:handle"

      result =
        CriticalEventDispatcher.execute(event_id, handler_ref, fn ->
          {:error, :something_went_wrong}
        end)

      assert result == {:error, :something_went_wrong}

      # Row should NOT exist — rolled back
      refute Repo.get_by(ProcessedEvent, event_id: event_id, handler_ref: handler_ref)
    end

    test "rolls back on handler crash and returns error" do
      event_id = Ecto.UUID.generate()
      handler_ref = "Elixir.TestModule:handle"

      result =
        CriticalEventDispatcher.execute(event_id, handler_ref, fn ->
          raise "boom"
        end)

      assert {:error, {:handler_crashed, %RuntimeError{message: "boom"}}} = result

      # Row should NOT exist — rolled back
      refute Repo.get_by(ProcessedEvent, event_id: event_id, handler_ref: handler_ref)
    end

    test "allows retry after failure (row was rolled back)" do
      event_id = Ecto.UUID.generate()
      handler_ref = "Elixir.TestModule:handle"
      test_pid = self()

      # First attempt fails
      {:error, _} =
        CriticalEventDispatcher.execute(event_id, handler_ref, fn ->
          {:error, :transient}
        end)

      # Retry succeeds — row was not left behind
      :ok =
        CriticalEventDispatcher.execute(event_id, handler_ref, fn ->
          send(test_pid, :retry_succeeded)
          :ok
        end)

      assert_received :retry_succeeded
      assert Repo.get_by(ProcessedEvent, event_id: event_id, handler_ref: handler_ref)
    end
  end
```

Also add these aliases at the top of the test module:

```elixir
  alias KlassHero.Repo
  alias KlassHero.Shared.Adapters.Driven.Persistence.Schemas.ProcessedEvent
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
mix test test/klass_hero/shared/domain/services/critical_event_dispatcher_test.exs --max-failures 1
```

Expected: FAIL — `execute/3` undefined.

- [ ] **Step 3: Write minimal implementation**

Add to `critical_event_dispatcher.ex`:

```elixir
  alias KlassHero.Repo
  alias KlassHero.Shared.Adapters.Driven.Persistence.Schemas.ProcessedEvent

  require Logger

  @doc """
  Executes a handler exactly once for a given event-handler pair.

  Uses a database transaction to atomically:
  1. Insert a `processed_events` row (ON CONFLICT DO NOTHING)
  2. If inserted (not a duplicate), run the handler function
  3. If handler succeeds, commit — row persists as proof of processing
  4. If handler fails or crashes, rollback — row removed, allowing retry

  Returns `:ok` if the handler ran successfully or was already processed.
  Returns `{:error, reason}` if the handler failed (row is rolled back).
  """
  @spec execute(String.t(), String.t(), (-> :ok | {:error, term()})) :: :ok | {:error, term()}
  def execute(event_id, handler_ref, handler_fn)
      when is_binary(event_id) and is_binary(handler_ref) and is_function(handler_fn, 0) do
    Repo.transaction(fn ->
      case insert_processed_event(event_id, handler_ref) do
        # Trigger: event-handler pair already in processed_events
        # Why: another delivery path (PubSub or earlier Oban attempt) already handled it
        # Outcome: skip handler, return :ok (idempotent no-op)
        :already_processed ->
          :ok

        # Trigger: row inserted — this is the first attempt for this pair
        # Why: handler must run inside the transaction so rollback removes the row on failure
        # Outcome: handler runs, success commits, failure rolls back
        :inserted ->
          run_handler(handler_fn)
      end
    end)
    |> unwrap_transaction_result()
  end

  defp insert_processed_event(event_id, handler_ref) do
    now = DateTime.utc_now()

    result =
      Repo.insert_all(
        ProcessedEvent,
        [%{event_id: event_id, handler_ref: handler_ref, processed_at: now}],
        on_conflict: :nothing
      )

    case result do
      {1, _} -> :inserted
      {0, _} -> :already_processed
    end
  end

  defp run_handler(handler_fn) do
    case handler_fn.() do
      :ok -> :ok
      {:error, reason} -> Repo.rollback({:handler_failed, reason})
    end
  rescue
    error ->
      Repo.rollback({:handler_crashed, error})
  end

  defp unwrap_transaction_result({:ok, :ok}), do: :ok

  defp unwrap_transaction_result({:error, {:handler_failed, reason}}),
    do: {:error, reason}

  defp unwrap_transaction_result({:error, {:handler_crashed, error}}),
    do: {:error, {:handler_crashed, error}}
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
mix test test/klass_hero/shared/domain/services/critical_event_dispatcher_test.exs
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add test/klass_hero/shared/domain/services/critical_event_dispatcher_test.exs lib/klass_hero/shared/domain/services/critical_event_dispatcher.ex
git commit -m "Add CriticalEventDispatcher.execute/3 with transactional idempotency (#325)"
```

---

### Task 4: CriticalEventDispatcher — `mark_processed/2`

**Files:**
- Modify: `test/klass_hero/shared/domain/services/critical_event_dispatcher_test.exs`
- Modify: `lib/klass_hero/shared/domain/services/critical_event_dispatcher.ex`

- [ ] **Step 1: Write failing tests for `mark_processed/2`**

Add to the test file:

```elixir
  describe "mark_processed/2" do
    test "inserts a processed_events row" do
      event_id = Ecto.UUID.generate()
      handler_ref = "Elixir.TestModule:handle"

      assert :ok = CriticalEventDispatcher.mark_processed(event_id, handler_ref)
      assert Repo.get_by(ProcessedEvent, event_id: event_id, handler_ref: handler_ref)
    end

    test "is idempotent — second call is a no-op" do
      event_id = Ecto.UUID.generate()
      handler_ref = "Elixir.TestModule:handle"

      assert :ok = CriticalEventDispatcher.mark_processed(event_id, handler_ref)
      assert :ok = CriticalEventDispatcher.mark_processed(event_id, handler_ref)
    end
  end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
mix test test/klass_hero/shared/domain/services/critical_event_dispatcher_test.exs --max-failures 1
```

Expected: FAIL — `mark_processed/2` undefined.

- [ ] **Step 3: Write minimal implementation**

Add to `critical_event_dispatcher.ex`:

```elixir
  @doc """
  Marks an event-handler pair as processed without running a handler.

  Used by `EventDispatchHelper` when a critical domain event's handler already
  succeeded synchronously via `DomainEventBus`. Inserts the `processed_events`
  row so any subsequent Oban retry is a no-op.

  Idempotent — calling twice with the same args is safe.
  """
  @spec mark_processed(String.t(), String.t()) :: :ok
  def mark_processed(event_id, handler_ref)
      when is_binary(event_id) and is_binary(handler_ref) do
    insert_processed_event(event_id, handler_ref)
    :ok
  end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
mix test test/klass_hero/shared/domain/services/critical_event_dispatcher_test.exs
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add test/klass_hero/shared/domain/services/critical_event_dispatcher_test.exs lib/klass_hero/shared/domain/services/critical_event_dispatcher.ex
git commit -m "Add CriticalEventDispatcher.mark_processed/2 (#325)"
```

---

## Chunk 2: Serializer and Registry

### Task 5: CriticalEventSerializer

**Files:**
- Create: `test/klass_hero/shared/adapters/driven/events/critical_event_serializer_test.exs`
- Create: `lib/klass_hero/shared/adapters/driven/events/critical_event_serializer.ex`

**Docs to check:** `lib/klass_hero/shared/domain/events/domain_event.ex`, `lib/klass_hero/shared/domain/events/integration_event.ex` for struct fields.

- [ ] **Step 1: Write failing tests**

Create `test/klass_hero/shared/adapters/driven/events/critical_event_serializer_test.exs`:

```elixir
defmodule KlassHero.Shared.Adapters.Driven.Events.CriticalEventSerializerTest do
  use ExUnit.Case, async: true

  alias KlassHero.Shared.Adapters.Driven.Events.CriticalEventSerializer
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  describe "DomainEvent round-trip" do
    test "serialize then deserialize produces equivalent struct" do
      event =
        DomainEvent.new(:user_registered, 42, :user, %{email: "test@example.com"},
          criticality: :critical,
          correlation_id: "corr-123"
        )

      serialized = CriticalEventSerializer.serialize(event)
      deserialized = CriticalEventSerializer.deserialize(serialized)

      assert deserialized.event_id == event.event_id
      assert deserialized.event_type == :user_registered
      assert deserialized.aggregate_id == 42
      assert deserialized.aggregate_type == :user
      assert deserialized.payload == %{email: "test@example.com"}
      assert deserialized.metadata.criticality == :critical
      assert deserialized.metadata.correlation_id == "corr-123"
      assert %DateTime{} = deserialized.occurred_at
    end

    test "serialized form uses string keys and string values for atoms" do
      event = DomainEvent.new(:test_event, "uuid-1", :test, %{key: "value"})
      serialized = CriticalEventSerializer.serialize(event)

      assert serialized["event_kind"] == "domain"
      assert serialized["event_type"] == "test_event"
      assert serialized["aggregate_type"] == "test"
      assert is_binary(serialized["occurred_at"])
    end
  end

  describe "IntegrationEvent round-trip" do
    test "serialize then deserialize produces equivalent struct" do
      event =
        IntegrationEvent.new(
          :child_data_anonymized,
          :family,
          :child,
          "child-uuid",
          %{child_id: "child-uuid", reason: "gdpr_request"},
          criticality: :critical,
          version: 2
        )

      serialized = CriticalEventSerializer.serialize(event)
      deserialized = CriticalEventSerializer.deserialize(serialized)

      assert deserialized.event_id == event.event_id
      assert deserialized.event_type == :child_data_anonymized
      assert deserialized.source_context == :family
      assert deserialized.entity_type == :child
      assert deserialized.entity_id == "child-uuid"
      assert deserialized.payload == %{child_id: "child-uuid", reason: "gdpr_request"}
      assert deserialized.metadata.criticality == :critical
      assert deserialized.version == 2
    end

    test "serialized form includes version and source_context" do
      event =
        IntegrationEvent.new(:test, :enrollment, :invite, "id", %{}, version: 3)

      serialized = CriticalEventSerializer.serialize(event)

      assert serialized["event_kind"] == "integration"
      assert serialized["source_context"] == "enrollment"
      assert serialized["version"] == 3
    end
  end

  describe "payload key atomization" do
    test "restores atom keys after JSON round-trip" do
      event = DomainEvent.new(:test, "id", :test, %{user_id: 1, name: "Alice"})
      serialized = CriticalEventSerializer.serialize(event)

      # Simulate JSON round-trip (keys become strings)
      json_cycled = Jason.decode!(Jason.encode!(serialized))

      deserialized = CriticalEventSerializer.deserialize(json_cycled)

      assert deserialized.payload == %{user_id: 1, name: "Alice"}
    end

    test "handles nested payload maps" do
      event = DomainEvent.new(:test, "id", :test, %{address: %{city: "Berlin", zip: "10115"}})
      serialized = CriticalEventSerializer.serialize(event)
      json_cycled = Jason.decode!(Jason.encode!(serialized))
      deserialized = CriticalEventSerializer.deserialize(json_cycled)

      assert deserialized.payload == %{address: %{city: "Berlin", zip: "10115"}}
    end
  end

  describe "metadata round-trip" do
    test "restores metadata atom keys after JSON round-trip" do
      event =
        DomainEvent.new(:test, "id", :test, %{},
          criticality: :critical,
          correlation_id: "corr-1",
          causation_id: "cause-1",
          user_id: 42
        )

      serialized = CriticalEventSerializer.serialize(event)
      json_cycled = Jason.decode!(Jason.encode!(serialized))
      deserialized = CriticalEventSerializer.deserialize(json_cycled)

      assert deserialized.metadata.criticality == :critical
      assert deserialized.metadata.correlation_id == "corr-1"
      assert deserialized.metadata.causation_id == "cause-1"
      assert deserialized.metadata.user_id == 42
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
mix test test/klass_hero/shared/adapters/driven/events/critical_event_serializer_test.exs --max-failures 1
```

Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

Create `lib/klass_hero/shared/adapters/driven/events/critical_event_serializer.ex`:

```elixir
defmodule KlassHero.Shared.Adapters.Driven.Events.CriticalEventSerializer do
  @moduledoc """
  Serializes and deserializes event structs for Oban job args.

  Handles the round-trip of `DomainEvent` and `IntegrationEvent` structs
  through JSON. Atom fields are converted to strings on serialization and
  restored via `String.to_existing_atom/1` on deserialization (safe because
  all event types and payload keys are domain-defined and already loaded).
  """

  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  @doc """
  Serializes an event struct into a JSON-safe map.
  """
  @spec serialize(DomainEvent.t() | IntegrationEvent.t()) :: map()
  def serialize(%DomainEvent{} = event) do
    %{
      "event_kind" => "domain",
      "event_id" => event.event_id,
      "event_type" => Atom.to_string(event.event_type),
      "aggregate_id" => event.aggregate_id,
      "aggregate_type" => Atom.to_string(event.aggregate_type),
      "occurred_at" => DateTime.to_iso8601(event.occurred_at),
      "payload" => stringify_keys(event.payload),
      "metadata" => serialize_metadata(event.metadata)
    }
  end

  def serialize(%IntegrationEvent{} = event) do
    %{
      "event_kind" => "integration",
      "event_id" => event.event_id,
      "event_type" => Atom.to_string(event.event_type),
      "source_context" => Atom.to_string(event.source_context),
      "entity_type" => Atom.to_string(event.entity_type),
      "entity_id" => event.entity_id,
      "occurred_at" => DateTime.to_iso8601(event.occurred_at),
      "payload" => stringify_keys(event.payload),
      "metadata" => serialize_metadata(event.metadata),
      "version" => event.version
    }
  end

  @doc """
  Deserializes a map (from Oban job args) back into an event struct.

  Atom fields are restored via `String.to_existing_atom/1`. Payload keys
  are atomized recursively.
  """
  @spec deserialize(map()) :: DomainEvent.t() | IntegrationEvent.t()
  def deserialize(%{"event_kind" => "domain"} = data) do
    %DomainEvent{
      event_id: data["event_id"],
      event_type: to_existing_atom(data["event_type"]),
      aggregate_id: data["aggregate_id"],
      aggregate_type: to_existing_atom(data["aggregate_type"]),
      occurred_at: parse_datetime!(data["occurred_at"]),
      payload: atomize_keys(data["payload"]),
      metadata: deserialize_metadata(data["metadata"])
    }
  end

  def deserialize(%{"event_kind" => "integration"} = data) do
    %IntegrationEvent{
      event_id: data["event_id"],
      event_type: to_existing_atom(data["event_type"]),
      source_context: to_existing_atom(data["source_context"]),
      entity_type: to_existing_atom(data["entity_type"]),
      entity_id: data["entity_id"],
      occurred_at: parse_datetime!(data["occurred_at"]),
      payload: atomize_keys(data["payload"]),
      metadata: deserialize_metadata(data["metadata"]),
      version: data["version"]
    }
  end

  # -- Key conversion helpers --

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), stringify_keys(v)}
      {k, v} -> {k, stringify_keys(v)}
    end)
  end

  defp stringify_keys(value), do: value

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), atomize_keys(v)}
      {k, v} -> {k, atomize_keys(v)}
    end)
  end

  defp atomize_keys(value), do: value

  # -- Metadata serialization --

  # Trigger: metadata contains a mix of atom values (:critical, :normal) and strings
  # Why: criticality is an atom enum, other metadata values are strings/integers
  # Outcome: atom values serialized to strings, restored on deserialization
  defp serialize_metadata(metadata) when is_map(metadata) do
    Map.new(metadata, fn
      {k, v} when is_atom(k) and is_atom(v) ->
        {Atom.to_string(k), Atom.to_string(v)}

      {k, v} when is_atom(k) ->
        {Atom.to_string(k), v}

      {k, v} ->
        {to_string(k), v}
    end)
  end

  @atom_metadata_values ~w(criticality)

  defp deserialize_metadata(metadata) when is_map(metadata) do
    Map.new(metadata, fn
      {k, v} when is_binary(k) and k in @atom_metadata_values ->
        {String.to_existing_atom(k), String.to_existing_atom(v)}

      {k, v} when is_binary(k) ->
        {String.to_existing_atom(k), v}

      {k, v} when is_atom(k) ->
        {k, v}
    end)
  end

  defp deserialize_metadata(nil), do: %{}

  # -- DateTime parsing --

  defp parse_datetime!(iso_string) when is_binary(iso_string) do
    {:ok, dt, _offset} = DateTime.from_iso8601(iso_string)
    dt
  end

  defp to_existing_atom(string) when is_binary(string), do: String.to_existing_atom(string)
  defp to_existing_atom(atom) when is_atom(atom), do: atom
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
mix test test/klass_hero/shared/adapters/driven/events/critical_event_serializer_test.exs
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add test/klass_hero/shared/adapters/driven/events/critical_event_serializer_test.exs lib/klass_hero/shared/adapters/driven/events/critical_event_serializer.ex
git commit -m "Add CriticalEventSerializer for event struct JSON round-trip (#325)"
```

---

### Task 6: CriticalEventHandlerRegistry

**Files:**
- Create: `test/klass_hero/shared/adapters/driven/events/critical_event_handler_registry_test.exs`
- Create: `lib/klass_hero/shared/adapters/driven/events/critical_event_handler_registry.ex`
- Modify: `config/config.exs` (add `:critical_event_handlers` config)
- Modify: `config/test.exs` (add test config)

- [ ] **Step 1: Write failing tests**

Create `test/klass_hero/shared/adapters/driven/events/critical_event_handler_registry_test.exs`:

```elixir
defmodule KlassHero.Shared.Adapters.Driven.Events.CriticalEventHandlerRegistryTest do
  use ExUnit.Case, async: true

  alias KlassHero.Shared.Adapters.Driven.Events.CriticalEventHandlerRegistry

  describe "handlers_for/1" do
    test "returns handler tuples for a configured topic" do
      # Uses whatever is in test config
      handlers =
        CriticalEventHandlerRegistry.handlers_for(
          "integration:enrollment:invite_claimed"
        )

      assert is_list(handlers)
      assert length(handlers) > 0
      assert {module, function} = hd(handlers)
      assert is_atom(module)
      assert is_atom(function)
    end

    test "returns empty list for unconfigured topic" do
      assert [] == CriticalEventHandlerRegistry.handlers_for("integration:unknown:topic")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/klass_hero/shared/adapters/driven/events/critical_event_handler_registry_test.exs --max-failures 1
```

Expected: FAIL — module not found.

- [ ] **Step 3: Add config entries**

Add to `config/config.exs` (after the existing `:integration_event_publisher` config):

```elixir
# Critical event handler registry — maps integration event topics to handlers
# that must be durably delivered via Oban. Only critical event subscriptions
# are registered here; non-critical events use PubSub-only delivery.
config :klass_hero, :critical_event_handlers, %{
  "integration:enrollment:invite_claimed" => [
    {KlassHero.Family.Adapters.Driven.Events.InviteClaimedHandler, :handle_event}
  ],
  "integration:family:invite_family_ready" => [
    {KlassHero.Enrollment.Adapters.Driven.Events.InviteFamilyReadyHandler, :handle_event}
  ]
}
```

Add test config to `config/test.exs` (after the existing `:integration_event_publisher` config):

```elixir
# Critical event handlers — same as production for integration testing
# Oban runs inline in tests, so these handlers execute synchronously
config :klass_hero, :critical_event_handlers, %{
  "integration:enrollment:invite_claimed" => [
    {KlassHero.Family.Adapters.Driven.Events.InviteClaimedHandler, :handle_event}
  ],
  "integration:family:invite_family_ready" => [
    {KlassHero.Enrollment.Adapters.Driven.Events.InviteFamilyReadyHandler, :handle_event}
  ]
}
```

Also add `critical_events: 5` to the Oban queues in `config/config.exs`:

```elixir
queues: [default: 10, messaging: 5, cleanup: 2, email: 5, family: 1, critical_events: 5]
```

- [ ] **Step 4: Write minimal implementation**

Create `lib/klass_hero/shared/adapters/driven/events/critical_event_handler_registry.ex`:

```elixir
defmodule KlassHero.Shared.Adapters.Driven.Events.CriticalEventHandlerRegistry do
  @moduledoc """
  Config-driven registry mapping integration event topics to handler modules.

  Used by `PubSubIntegrationEventPublisher` to look up which handlers need
  durable Oban-backed delivery for critical integration events. The mapping
  is defined in application config under `:critical_event_handlers`.

  Only critical event subscriptions are registered here. Non-critical events
  continue using `EventSubscriber` via PubSub only.
  """

  @doc """
  Returns handler `{module, function}` tuples for a given integration event topic.

  Returns an empty list if no handlers are configured for the topic.
  """
  @spec handlers_for(String.t()) :: [{module(), atom()}]
  def handlers_for(topic) when is_binary(topic) do
    :klass_hero
    |> Application.get_env(:critical_event_handlers, %{})
    |> Map.get(topic, [])
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
mix test test/klass_hero/shared/adapters/driven/events/critical_event_handler_registry_test.exs
```

Expected: All tests pass.

- [ ] **Step 6: Verify full compilation**

```bash
mix compile --warnings-as-errors
```

- [ ] **Step 7: Commit**

```bash
git add test/klass_hero/shared/adapters/driven/events/critical_event_handler_registry_test.exs lib/klass_hero/shared/adapters/driven/events/critical_event_handler_registry.ex config/config.exs config/test.exs
git commit -m "Add CriticalEventHandlerRegistry and critical_events Oban queue (#325)"
```

---

## Chunk 3: Oban Worker

### Task 7: CriticalEventWorker

**Files:**
- Create: `test/klass_hero/shared/adapters/driven/workers/critical_event_worker_test.exs`
- Create: `lib/klass_hero/shared/adapters/driven/workers/critical_event_worker.ex`

**Docs to check:** Existing Oban workers at `lib/klass_hero/enrollment/adapters/driven/workers/send_invite_email_worker.ex` for patterns.

- [ ] **Step 1: Write failing tests**

Create `test/klass_hero/shared/adapters/driven/workers/critical_event_worker_test.exs`:

```elixir
defmodule KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorkerTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Shared.Adapters.Driven.Events.CriticalEventSerializer
  alias KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorker
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.Domain.Events.IntegrationEvent
  alias KlassHero.Shared.Domain.Services.CriticalEventDispatcher

  describe "perform/1 with domain events" do
    test "deserializes event and dispatches via CriticalEventDispatcher" do
      event = DomainEvent.new(:test_handled, "agg-1", :test_aggregate, %{data: "value"})

      args =
        CriticalEventSerializer.serialize(event)
        |> Map.merge(%{
          "handler" => "Elixir.KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorkerTest.SuccessHandler:handle",
          "context" => "Elixir.KlassHero.TestContext"
        })

      job = %Oban.Job{args: args}
      assert :ok = CriticalEventWorker.perform(job)

      # Verify processed_events row was created
      ref = CriticalEventDispatcher.handler_ref(
        {KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorkerTest.SuccessHandler, :handle}
      )
      assert Repo.get_by(
        KlassHero.Shared.Adapters.Driven.Persistence.Schemas.ProcessedEvent,
        event_id: event.event_id,
        handler_ref: ref
      )
    end

    test "returns error when handler fails (triggers Oban retry)" do
      event = DomainEvent.new(:test_failed, "agg-1", :test_aggregate, %{})

      args =
        CriticalEventSerializer.serialize(event)
        |> Map.merge(%{
          "handler" => "Elixir.KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorkerTest.FailHandler:handle",
          "context" => "Elixir.KlassHero.TestContext"
        })

      job = %Oban.Job{args: args}
      assert {:error, :handler_broke} = CriticalEventWorker.perform(job)
    end
  end

  describe "perform/1 with integration events" do
    test "deserializes integration event and dispatches" do
      event =
        IntegrationEvent.new(:test_integration, :test_context, :entity, "ent-1", %{val: 1})

      args =
        CriticalEventSerializer.serialize(event)
        |> Map.merge(%{
          "handler" => "Elixir.KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorkerTest.SuccessHandler:handle"
        })

      job = %Oban.Job{args: args}
      assert :ok = CriticalEventWorker.perform(job)
    end
  end

  # Test handler modules
  defmodule SuccessHandler do
    def handle(_event), do: :ok
  end

  defmodule FailHandler do
    def handle(_event), do: {:error, :handler_broke}
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
mix test test/klass_hero/shared/adapters/driven/workers/critical_event_worker_test.exs --max-failures 1
```

Expected: FAIL — module not found.

- [ ] **Step 3: Write minimal implementation**

Create `lib/klass_hero/shared/adapters/driven/workers/critical_event_worker.ex`:

```elixir
defmodule KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorker do
  @moduledoc """
  Generic Oban worker for durable delivery of critical events.

  Deserializes the event from job args, reconstitutes the handler function,
  and dispatches through `CriticalEventDispatcher` for exactly-once execution.

  Used as a fallback when:
  - A critical domain event's handler failed during synchronous dispatch
  - A critical integration event needs durable delivery alongside PubSub
  """

  use Oban.Worker,
    queue: :critical_events,
    max_attempts: 3

  alias KlassHero.Shared.Adapters.Driven.Events.CriticalEventSerializer
  alias KlassHero.Shared.Domain.Services.CriticalEventDispatcher

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args, attempt: attempt, max_attempts: max_attempts}) do
    handler_ref_str = Map.fetch!(args, "handler")
    {module, function} = parse_handler_ref(handler_ref_str)
    event = CriticalEventSerializer.deserialize(args)

    result =
      CriticalEventDispatcher.execute(event.event_id, handler_ref_str, fn ->
        apply(module, function, [event])
      end)

    # Trigger: all retry attempts exhausted and handler still failing
    # Why: critical events that permanently fail need operator attention
    # Outcome: error-level log with full context for ErrorTracker alerting
    case result do
      {:error, reason} when attempt >= max_attempts ->
        Logger.error(
          "Critical event permanently failed after #{max_attempts} attempts: " <>
            "event_type=#{args["event_type"]} handler=#{handler_ref_str}",
          event_id: args["event_id"],
          event_type: args["event_type"],
          handler: handler_ref_str,
          reason: inspect(reason),
          attempt: attempt
        )

        result

      _ ->
        result
    end
  end

  # Trigger: handler ref stored as "Elixir.Module.Name:function" string
  # Why: Oban args are JSON — can't store module/function atoms directly
  # Outcome: reconstitute {module, function} tuple using existing atoms (safe
  #          because handler modules are loaded at boot via supervision tree)
  defp parse_handler_ref(handler_ref_str) do
    [module_str, function_str] = String.split(handler_ref_str, ":")
    {String.to_existing_atom(module_str), String.to_existing_atom(function_str)}
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
mix test test/klass_hero/shared/adapters/driven/workers/critical_event_worker_test.exs
```

Expected: All tests pass.

- [ ] **Step 5: Run full test suite so far**

```bash
mix test test/klass_hero/shared/domain/services/ test/klass_hero/shared/adapters/driven/events/critical_event_serializer_test.exs test/klass_hero/shared/adapters/driven/events/critical_event_handler_registry_test.exs test/klass_hero/shared/adapters/driven/workers/critical_event_worker_test.exs
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add test/klass_hero/shared/adapters/driven/workers/critical_event_worker_test.exs lib/klass_hero/shared/adapters/driven/workers/critical_event_worker.ex
git commit -m "Add CriticalEventWorker Oban worker for durable event delivery (#325)"
```

---

## Chunk 4: DomainEventBus Enhancement

### Task 8: `DomainEventBus.dispatch_critical/2`

**Files:**
- Modify: `test/klass_hero/shared/domain_event_bus_test.exs`
- Modify: `lib/klass_hero/shared/domain_event_bus.ex`

**Key change:** Handler entries must store their `{module, function}` origin alongside the captured function. Currently entries are `{handler_fn, opts}`. Change to `{handler_fn, opts, handler_identity}` where `handler_identity` is `{module, function}` for init-time handlers or `:anonymous` for runtime lambdas.

- [ ] **Step 1: Write failing tests**

Add to `test/klass_hero/shared/domain_event_bus_test.exs`:

```elixir
  # Add this test handler module at the top of the test file (inside the module):
  defmodule TestCriticalHandler do
    def handle(%DomainEvent{} = _event), do: :ok
  end

  defmodule TestCriticalFailHandler do
    def handle(%DomainEvent{} = _event), do: {:error, :critical_fail}
  end

  describe "dispatch_critical/2" do
    test "returns per-handler results with handler identity" do
      context = :"test_critical_#{System.unique_integer([:positive])}"

      start_supervised!(
        {DomainEventBus,
         context: context,
         handlers: [
           {:test_event, {TestCriticalHandler, :handle}}
         ]}
      )

      event = DomainEvent.new(:test_event, "agg-1", :test, %{})

      assert {:ok, results} = DomainEventBus.dispatch_critical(context, event)
      assert [{handler_identity, :ok}] = results
      assert handler_identity == {TestCriticalHandler, :handle}
    end

    test "includes handler identity in failure results" do
      context = :"test_critical_fail_#{System.unique_integer([:positive])}"

      start_supervised!(
        {DomainEventBus,
         context: context,
         handlers: [
           {:test_event, {TestCriticalHandler, :handle}},
           {:test_event, {TestCriticalFailHandler, :handle}}
         ]}
      )

      event = DomainEvent.new(:test_event, "agg-1", :test, %{})

      assert {:ok, results} = DomainEventBus.dispatch_critical(context, event)

      assert Enum.any?(results, fn
        {{TestCriticalHandler, :handle}, :ok} -> true
        _ -> false
      end)

      assert Enum.any?(results, fn
        {{TestCriticalFailHandler, :handle}, {:error, :critical_fail}} -> true
        _ -> false
      end)
    end

    test "anonymous handlers use :anonymous identity" do
      context = :"test_critical_anon_#{System.unique_integer([:positive])}"
      start_supervised!({DomainEventBus, context: context})

      DomainEventBus.subscribe(context, :test_event, fn _event -> :ok end)
      event = DomainEvent.new(:test_event, "agg-1", :test, %{})

      assert {:ok, results} = DomainEventBus.dispatch_critical(context, event)
      assert [{:anonymous, :ok}] = results
    end
  end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
mix test test/klass_hero/shared/domain_event_bus_test.exs --max-failures 1
```

Expected: FAIL — `dispatch_critical/2` undefined and `:get_context` not handled.

- [ ] **Step 3: Implement changes to DomainEventBus**

Modify `lib/klass_hero/shared/domain_event_bus.ex`:

**3a.** Change handler entry storage from `{handler_fn, opts}` to `{handler_fn, opts, handler_identity}`:

In `handle_call({:subscribe, ...})`, store `:anonymous` as identity:

```elixir
def handle_call({:subscribe, event_type, handler_fn, opts}, _from, state) do
  entry = {handler_fn, opts, :anonymous}
  handlers = Map.update(state.handlers, event_type, [entry], &(&1 ++ [entry]))
  {:reply, :ok, %{state | handlers: handlers}}
end
```

In `normalize_handler_spec/1`, store the `{module, function}` identity:

```elixir
defp normalize_handler_spec({event_type, {module, function}}) do
  {event_type, Function.capture(module, function, 1), [], {module, function}}
end

defp normalize_handler_spec({event_type, {module, function}, opts}) do
  {event_type, Function.capture(module, function, 1), opts, {module, function}}
end
```

Update `register_init_handlers/1`:

```elixir
defp register_init_handlers(specs) do
  Enum.reduce(specs, %{}, fn spec, acc ->
    {event_type, handler_fn, opts, identity} = normalize_handler_spec(spec)
    entry = {handler_fn, opts, identity}
    Map.update(acc, event_type, [entry], &(&1 ++ [entry]))
  end)
end
```

**3b.** Update `execute_handlers/2` to work with 3-element tuples:

```elixir
defp execute_handlers([], _event), do: :ok

defp execute_handlers(entries, event) do
  sorted =
    entries
    |> Enum.with_index()
    |> Enum.sort_by(fn {{_fn, opts, _identity}, index} ->
      {Keyword.get(opts, :priority, @default_priority), index}
    end)
    |> Enum.map(fn {{handler_fn, _opts, _identity}, _index} -> handler_fn end)

  failures =
    sorted
    |> Enum.map(&safe_call(&1, event))
    |> Enum.filter(&match?({:error, _}, &1))

  if failures == [], do: :ok, else: {:error, failures}
end
```

**3c.** Add `dispatch_critical/2` and `handle_call(:get_context, ...)`:

```elixir
@doc """
Dispatches a domain event and returns per-handler results with handler identity.

Unlike `dispatch/2` which returns a flat `:ok` or `{:error, failures}`, this
variant returns `{:ok, [{handler_identity, result}]}` so callers can determine
which specific handlers succeeded or failed — needed for critical event routing.
"""
@spec dispatch_critical(module(), DomainEvent.t()) ::
        {:ok, [{{module(), atom()} | :anonymous, :ok | {:error, term()}}]}
def dispatch_critical(context, %DomainEvent{event_type: event_type} = event) do
  handlers = GenServer.call(process_name(context), {:get_handlers, event_type})
  {:ok, execute_handlers_with_identity(handlers, event)}
end

defp execute_handlers_with_identity([], _event), do: []

defp execute_handlers_with_identity(entries, event) do
  sorted =
    entries
    |> Enum.with_index()
    |> Enum.sort_by(fn {{_fn, opts, _identity}, index} ->
      {Keyword.get(opts, :priority, @default_priority), index}
    end)

  Enum.map(sorted, fn {{handler_fn, _opts, identity}, _index} ->
    {identity, safe_call(handler_fn, event)}
  end)
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
mix test test/klass_hero/shared/domain_event_bus_test.exs
```

Expected: All tests pass (both existing and new).

- [ ] **Step 5: Commit**

```bash
git add test/klass_hero/shared/domain_event_bus_test.exs lib/klass_hero/shared/domain_event_bus.ex
git commit -m "Add DomainEventBus.dispatch_critical/2 with per-handler identity (#325)"
```

---

## Chunk 5: Wiring Into Existing Modules

### Task 9: EventDispatchHelper — Critical Domain Event Routing

**Files:**
- Modify: `test/klass_hero/shared/event_dispatch_helper_test.exs`
- Modify: `lib/klass_hero/shared/event_dispatch_helper.ex`

- [ ] **Step 1: Write failing tests**

**Important:** The existing test file uses `use ExUnit.Case, async: true`. Change it to `use KlassHero.DataCase, async: true` since the new tests need database access.

Also add these aliases at the top of the module:

```elixir
  alias KlassHero.Repo
  alias KlassHero.Shared.Adapters.Driven.Persistence.Schemas.ProcessedEvent
  alias KlassHero.Shared.Domain.Services.CriticalEventDispatcher
```

Add the following to `test/klass_hero/shared/event_dispatch_helper_test.exs`:

```elixir
  # Add test handler modules:
  defmodule CriticalSuccessHandler do
    def handle(%DomainEvent{} = _event), do: :ok
  end

  defmodule CriticalFailHandler do
    def handle(%DomainEvent{} = _event), do: {:error, :handler_broke}
  end

  describe "dispatch/2 with critical events" do
    setup do
      context = :"test_critical_dispatch_#{System.unique_integer([:positive])}"

      start_supervised!(
        {DomainEventBus,
         context: context,
         handlers: [
           {:critical_test, {CriticalSuccessHandler, :handle}}
         ]}
      )

      %{context: context}
    end

    test "marks handler as processed when critical event succeeds", %{context: context} do
      event = DomainEvent.new(:critical_test, "agg-1", :test, %{}, criticality: :critical)

      assert :ok = EventDispatchHelper.dispatch(event, context)

      handler_ref = CriticalEventDispatcher.handler_ref({CriticalSuccessHandler, :handle})
      assert Repo.get_by(ProcessedEvent, event_id: event.event_id, handler_ref: handler_ref)
    end

    test "does NOT mark as processed for normal events", %{context: context} do
      event = DomainEvent.new(:critical_test, "agg-1", :test, %{})

      assert :ok = EventDispatchHelper.dispatch(event, context)

      # No processed_events row for normal events
      assert [] == Repo.all(ProcessedEvent)
    end
  end

  describe "dispatch/2 critical event with failed handler" do
    setup do
      context = :"test_critical_fail_#{System.unique_integer([:positive])}"

      start_supervised!(
        {DomainEventBus,
         context: context,
         handlers: [
           {:critical_fail_test, {CriticalSuccessHandler, :handle}},
           {:critical_fail_test, {CriticalFailHandler, :handle}}
         ]}
      )

      %{context: context}
    end

    test "enqueues Oban job for failed handler and marks successful one", %{context: context} do
      event =
        DomainEvent.new(:critical_fail_test, "agg-1", :test, %{data: "val"},
          criticality: :critical
        )

      assert :ok = EventDispatchHelper.dispatch(event, context)

      # Successful handler should be marked processed
      success_ref = CriticalEventDispatcher.handler_ref({CriticalSuccessHandler, :handle})
      assert Repo.get_by(ProcessedEvent, event_id: event.event_id, handler_ref: success_ref)

      # Failed handler should have an Oban job enqueued
      # (In test mode with Oban :inline, the job runs immediately — so it will
      #  also fail and the processed_events row won't exist)
      fail_ref = CriticalEventDispatcher.handler_ref({CriticalFailHandler, :handle})
      refute Repo.get_by(ProcessedEvent, event_id: event.event_id, handler_ref: fail_ref)
    end
  end

  describe "dispatch_or_error/2 with critical events" do
    setup do
      context = :"test_critical_or_error_#{System.unique_integer([:positive])}"

      start_supervised!(
        {DomainEventBus,
         context: context,
         handlers: [
           {:critical_or_error_test, {CriticalFailHandler, :handle}}
         ]}
      )

      %{context: context}
    end

    test "does NOT enqueue Oban job — caller owns error handling", %{context: context} do
      event =
        DomainEvent.new(:critical_or_error_test, "agg-1", :test, %{}, criticality: :critical)

      assert {:error, _reason} = EventDispatchHelper.dispatch_or_error(event, context)

      # No Oban job — dispatch_or_error lets caller handle the failure
      # No processed_events row either
      assert [] == Repo.all(ProcessedEvent)
    end
  end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
mix test test/klass_hero/shared/event_dispatch_helper_test.exs --max-failures 1
```

Expected: FAIL — new tests fail because `dispatch/2` doesn't handle critical events yet.

- [ ] **Step 3: Implement changes to EventDispatchHelper**

Modify `lib/klass_hero/shared/event_dispatch_helper.ex`:

```elixir
defmodule KlassHero.Shared.EventDispatchHelper do
  @moduledoc """
  Fire-and-forget event dispatch with criticality-aware logging and
  durable delivery for critical events.

  Wraps `DomainEventBus.dispatch/2` so callers never need to handle
  dispatch failures — the helper logs at the appropriate level based
  on event criticality and always returns `:ok`.

  For critical events, failed handlers are automatically retried via Oban.
  """

  alias KlassHero.Shared.Adapters.Driven.Events.CriticalEventSerializer
  alias KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorker
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.Domain.Services.CriticalEventDispatcher
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @doc """
  Dispatches a domain event and logs failures at the appropriate level.

  For critical events:
  - Uses `DomainEventBus.dispatch_critical/2` to get per-handler results
  - Marks successful handlers as processed (idempotency gate)
  - Enqueues Oban retry jobs for failed handlers

  For normal events:
  - Uses `DomainEventBus.dispatch/2` (fire-and-forget, unchanged)

  Always returns `:ok` — dispatch failures never propagate to callers.
  """
  @spec dispatch(DomainEvent.t(), module()) :: :ok
  def dispatch(%DomainEvent{} = event, context) do
    if DomainEvent.critical?(event) do
      dispatch_critical(event, context)
    else
      dispatch_normal(event, context)
    end
  end

  @doc """
  Dispatches a domain event and propagates the first handler failure.

  Unlike `dispatch/2` (fire-and-forget), this variant returns `{:error, reason}`
  when any handler fails — useful in `with` chains where dispatch failure must
  halt the pipeline.

  For critical events, this does NOT enqueue Oban jobs. The caller owns error
  handling — they receive `{:error, reason}` and can roll back their own
  transaction. Enqueueing a retry would conflict with the caller's rollback.
  """
  @spec dispatch_or_error(DomainEvent.t(), module()) :: :ok | {:error, term()}
  def dispatch_or_error(%DomainEvent{} = event, context) do
    if DomainEvent.critical?(event) do
      {:ok, results} = DomainEventBus.dispatch_critical(context, event)

      case Enum.find(results, fn {_identity, result} -> match?({:error, _}, result) end) do
        nil -> :ok
        {_identity, {:error, reason}} -> {:error, reason}
      end
    else
      case DomainEventBus.dispatch(context, event) do
        :ok -> :ok
        {:error, [first_failure | _]} -> normalize_failure(first_failure)
      end
    end
  end

  # -- Critical event dispatch --

  # Trigger: event has criticality: :critical
  # Why: critical events must not be silently lost — failed handlers get Oban retry
  # Outcome: successful handlers marked as processed, failed handlers enqueued for retry
  defp dispatch_critical(%DomainEvent{} = event, context) do
    {:ok, results} = DomainEventBus.dispatch_critical(context, event)

    Enum.each(results, fn
      {identity, :ok} when identity != :anonymous ->
        ref = CriticalEventDispatcher.handler_ref(identity)
        CriticalEventDispatcher.mark_processed(event.event_id, ref)

      {identity, {:error, _reason}} when identity != :anonymous ->
        enqueue_critical_retry(event, identity, context)

      # Trigger: anonymous handlers (runtime-subscribed lambdas) have no identity
      # Why: can't serialize anonymous functions for Oban — no retry possible
      # Outcome: log and skip, same as normal event dispatch
      {_identity, {:error, _} = failure} ->
        log_dispatch_failure(event, [failure])

      _ ->
        :ok
    end)

    :ok
  end

  defp dispatch_normal(%DomainEvent{} = event, context) do
    case DomainEventBus.dispatch(context, event) do
      :ok ->
        :ok

      {:error, failures} ->
        log_dispatch_failure(event, failures)
        :ok
    end
  end

  defp enqueue_critical_retry(%DomainEvent{} = event, {module, function}, context) do
    handler_ref = CriticalEventDispatcher.handler_ref({module, function})

    args =
      CriticalEventSerializer.serialize(event)
      |> Map.merge(%{
        "handler" => handler_ref,
        "context" => inspect(context)
      })

    case Oban.insert(CriticalEventWorker.new(args)) do
      {:ok, _job} ->
        Logger.info(
          "Enqueued critical event retry: event_type=#{event.event_type} handler=#{handler_ref}",
          event_id: event.event_id,
          event_type: event.event_type,
          handler: handler_ref
        )

      {:error, reason} ->
        Logger.error(
          "Failed to enqueue critical event retry: event_type=#{event.event_type} handler=#{handler_ref}",
          event_id: event.event_id,
          reason: inspect(reason)
        )
    end
  end

  # Trigger: critical events (e.g. GDPR anonymization) fail to dispatch
  # Why: critical events represent business-critical data that must not be silently lost
  # Outcome: error-level log ensures alerting systems catch the failure
  defp log_dispatch_failure(%DomainEvent{} = event, failures) do
    if DomainEvent.critical?(event) do
      Logger.error(
        "Critical event dispatch failed: event_type=#{event.event_type} failures=#{inspect(failures)}"
      )
    else
      Logger.warning(
        "Event dispatch failed: event_type=#{event.event_type} failures=#{inspect(failures)}"
      )
    end
  end

  # Trigger: DomainEventBus returns error tuples in various shapes
  # Why: bus can produce {:error, reason}, {:error, {:handler_crashed, e}}, or bare terms
  # Outcome: normalizes all shapes to a flat {:error, reason}
  defp normalize_failure({:error, reason}), do: {:error, reason}
  defp normalize_failure(other), do: {:error, other}
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
mix test test/klass_hero/shared/event_dispatch_helper_test.exs
```

Expected: All tests pass (both existing and new).

- [ ] **Step 5: Run full test suite**

```bash
mix test
```

Expected: All tests pass. No regressions.

- [ ] **Step 6: Commit**

```bash
git add test/klass_hero/shared/event_dispatch_helper_test.exs lib/klass_hero/shared/event_dispatch_helper.ex
git commit -m "Wire critical domain events through CriticalEventDispatcher in EventDispatchHelper (#325)"
```

---

### Task 10: EventSubscriber — Critical Integration Event Wrapping

**Files:**
- Modify: `test/klass_hero/shared/adapters/driven/events/event_subscriber_integration_test.exs`
- Modify: `lib/klass_hero/shared/adapters/driven/events/event_subscriber.ex`

- [ ] **Step 1: Write failing tests**

**Important:** The existing integration test file uses `use ExUnit.Case, async: false`. Change it to `use KlassHero.DataCase, async: false` since the new tests need database access. Add these aliases:

```elixir
  alias KlassHero.Repo
  alias KlassHero.Shared.Adapters.Driven.Persistence.Schemas.ProcessedEvent
  alias KlassHero.Shared.Domain.Events.IntegrationEvent
  alias KlassHero.Shared.Domain.Services.CriticalEventDispatcher
```

Create a separate test handler module in `test/support/critical_test_handler.ex` (since it needs to be a proper module, not defined inline):

```elixir
defmodule KlassHero.Test.CriticalTestHandler do
  @moduledoc false
  @behaviour KlassHero.Shared.Domain.Ports.ForHandlingIntegrationEvents

  @impl true
  def subscribed_events, do: [:critical_test_event]

  @impl true
  def handle_event(%KlassHero.Shared.Domain.Events.IntegrationEvent{} = _event), do: :ok
  def handle_event(_event), do: :ignore
end
```

Then add to `test/klass_hero/shared/adapters/driven/events/event_subscriber_integration_test.exs`:

```elixir
  describe "critical integration event handling" do
    test "wraps critical event handler in CriticalEventDispatcher" do
      handler = KlassHero.Test.CriticalTestHandler

      # Start subscriber
      {:ok, _pid} =
        EventSubscriber.start_link(
          handler: handler,
          topics: ["integration:test:critical_test_event"],
          message_tag: :integration_event,
          event_label: "Integration event",
          name: :"critical_test_sub_#{System.unique_integer([:positive])}"
        )

      # Publish a critical integration event
      event =
        IntegrationEvent.new(:critical_test_event, :test, :entity, "ent-1", %{},
          criticality: :critical
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:test:critical_test_event",
        {:integration_event, event}
      )

      # Give the subscriber time to process
      Process.sleep(100)

      # Verify processed_events row was created
      handler_ref = CriticalEventDispatcher.handler_ref({handler, :handle_event})
      assert Repo.get_by(ProcessedEvent, event_id: event.event_id, handler_ref: handler_ref)
    end

    test "normal integration events bypass CriticalEventDispatcher" do
      handler = KlassHero.Test.CriticalTestHandler

      {:ok, _pid} =
        EventSubscriber.start_link(
          handler: handler,
          topics: ["integration:test:critical_test_event"],
          message_tag: :integration_event,
          event_label: "Integration event",
          name: :"normal_test_sub_#{System.unique_integer([:positive])}"
        )

      # Publish a NORMAL integration event (no criticality)
      event =
        IntegrationEvent.new(:critical_test_event, :test, :entity, "ent-2", %{})

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:test:critical_test_event",
        {:integration_event, event}
      )

      Process.sleep(100)

      # No processed_events row — normal events bypass dispatcher
      assert [] == Repo.all(ProcessedEvent)
    end
  end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
mix test test/klass_hero/shared/adapters/driven/events/event_subscriber_integration_test.exs --max-failures 1
```

Expected: FAIL — no processed_events row created (EventSubscriber doesn't call dispatcher yet).

- [ ] **Step 3: Implement changes to EventSubscriber**

Modify `lib/klass_hero/shared/adapters/driven/events/event_subscriber.ex`:

Add aliases at the top:

```elixir
alias KlassHero.Shared.Domain.Events.IntegrationEvent
alias KlassHero.Shared.Domain.Services.CriticalEventDispatcher
```

Replace the `handle_event_safely/2` function:

```elixir
defp handle_event_safely(event, %{handler: handler, event_label: label}) do
  # Trigger: integration event may be marked critical
  # Why: critical events need exactly-once processing via processed_events gate
  # Outcome: critical events go through CriticalEventDispatcher, normal events
  #          are handled directly as before
  if critical_integration_event?(event) do
    handle_critical_event(event, handler, label)
  else
    handle_normal_event(event, handler, label)
  end
rescue
  error ->
    Logger.error(
      "Handler #{inspect(handler)} crashed handling #{String.downcase(label)} #{event.event_type}: #{Exception.message(error)}",
      stacktrace: Exception.format_stacktrace(__STACKTRACE__)
    )
end

defp critical_integration_event?(%IntegrationEvent{} = event),
  do: IntegrationEvent.critical?(event)

defp critical_integration_event?(_event), do: false

defp handle_critical_event(event, handler, label) do
  handler_ref = CriticalEventDispatcher.handler_ref({handler, :handle_event})

  case CriticalEventDispatcher.execute(event.event_id, handler_ref, fn ->
         handler.handle_event(event)
       end) do
    :ok ->
      Logger.debug("#{label} #{event.event_type} handled by #{inspect(handler)} (critical, processed)")

    {:error, reason} ->
      Logger.error(
        "Handler #{inspect(handler)} failed to handle critical #{String.downcase(label)} #{event.event_type}: #{inspect(reason)}"
      )
  end
end

defp handle_normal_event(event, handler, label) do
  case handler.handle_event(event) do
    :ok ->
      Logger.debug("#{label} #{event.event_type} handled by #{inspect(handler)}")

    :ignore ->
      Logger.debug("#{label} #{event.event_type} ignored by #{inspect(handler)}")

    {:error, reason} ->
      Logger.error(
        "Handler #{inspect(handler)} failed to handle #{String.downcase(label)} #{event.event_type}: #{inspect(reason)}"
      )

    unexpected ->
      Logger.warning(
        "Handler #{inspect(handler)} returned unexpected value for #{String.downcase(label)} #{event.event_type}: #{inspect(unexpected)}"
      )
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
mix test test/klass_hero/shared/adapters/driven/events/event_subscriber_integration_test.exs
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add test/support/critical_test_handler.ex test/klass_hero/shared/adapters/driven/events/event_subscriber_integration_test.exs lib/klass_hero/shared/adapters/driven/events/event_subscriber.ex
git commit -m "Wrap critical integration events in CriticalEventDispatcher in EventSubscriber (#325)"
```

---

### Task 11: PubSubIntegrationEventPublisher — Dual Delivery

**Files:**
- Modify: `lib/klass_hero/shared/adapters/driven/events/pubsub_integration_event_publisher.ex`

**Note:** Testing dual delivery end-to-end requires integration tests. We write unit tests for the Oban job enqueue logic and verify via the existing integration test infrastructure.

- [ ] **Step 1: Write failing test**

Create or add to an existing test file for the publisher. Since the publisher currently has no dedicated test file, add a test:

Create `test/klass_hero/shared/adapters/driven/events/pubsub_integration_event_publisher_test.exs`:

```elixir
defmodule KlassHero.Shared.Adapters.Driven.Events.PubSubIntegrationEventPublisherTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Shared.Adapters.Driven.Events.PubSubIntegrationEventPublisher
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  describe "publish/1 with critical integration events" do
    test "enqueues Oban jobs for critical events with registered handlers" do
      event =
        IntegrationEvent.new(
          :invite_claimed,
          :enrollment,
          :invite,
          "invite-1",
          %{user_id: 1},
          criticality: :critical
        )

      # Count Oban jobs before
      jobs_before = Repo.all(Oban.Job) |> length()

      # Publish the event — PubSub broadcast + Oban job enqueue
      assert :ok = PubSubIntegrationEventPublisher.publish(event)

      # Verify Oban job was created (in :inline mode it runs immediately,
      # but the job row still exists in the DB)
      jobs_after = Repo.all(Oban.Job) |> length()
      assert jobs_after > jobs_before
    end

    test "does not enqueue Oban jobs for normal events" do
      jobs_before = Repo.all(Oban.Job) |> length()

      event =
        IntegrationEvent.new(
          :some_normal_event,
          :enrollment,
          :invite,
          "invite-1",
          %{}
        )

      # Normal events should just broadcast — no Oban jobs
      assert :ok = PubSubIntegrationEventPublisher.publish(event)

      # No new Oban jobs
      jobs_after = Repo.all(Oban.Job) |> length()
      assert jobs_after == jobs_before
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails (or passes trivially)**

```bash
mix test test/klass_hero/shared/adapters/driven/events/pubsub_integration_event_publisher_test.exs
```

The test may pass trivially since `publish/1` already returns `:ok`. The real verification is that critical events trigger Oban job creation.

- [ ] **Step 3: Implement dual delivery in PubSubIntegrationEventPublisher**

Modify `lib/klass_hero/shared/adapters/driven/events/pubsub_integration_event_publisher.ex`:

Add aliases:

```elixir
alias KlassHero.Shared.Adapters.Driven.Events.CriticalEventHandlerRegistry
alias KlassHero.Shared.Adapters.Driven.Events.CriticalEventSerializer
alias KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorker
alias KlassHero.Shared.Domain.Services.CriticalEventDispatcher
```

Modify `publish/1` to add Oban job enqueue after PubSub broadcast:

```elixir
@impl true
def publish(%IntegrationEvent{} = event) do
  topic = derive_topic(event)

  case publish(event, topic) do
    :ok ->
      # Trigger: event may be marked critical
      # Why: critical integration events need durable delivery as Oban fallback
      # Outcome: one CriticalEventWorker job enqueued per registered handler
      maybe_enqueue_critical_jobs(event, topic)
      :ok

    error ->
      error
  end
end
```

Add the private helper:

```elixir
# Trigger: event has criticality: :critical and handlers are registered
# Why: PubSub is fire-and-forget — Oban provides durable retry if PubSub path fails
# Outcome: one Oban job per handler, each going through CriticalEventDispatcher
defp maybe_enqueue_critical_jobs(%IntegrationEvent{} = event, topic) do
  if IntegrationEvent.critical?(event) do
    handlers = CriticalEventHandlerRegistry.handlers_for(topic)

    Enum.each(handlers, fn {module, function} = handler_tuple ->
      handler_ref = CriticalEventDispatcher.handler_ref(handler_tuple)

      args =
        CriticalEventSerializer.serialize(event)
        |> Map.put("handler", handler_ref)

      case Oban.insert(CriticalEventWorker.new(args)) do
        {:ok, _job} ->
          Logger.debug(
            "Enqueued critical integration event job: #{event.event_type} → #{handler_ref}",
            event_id: event.event_id,
            handler: handler_ref
          )

        {:error, reason} ->
          Logger.error(
            "Failed to enqueue critical integration event job: #{event.event_type} → #{handler_ref}",
            event_id: event.event_id,
            reason: inspect(reason)
          )
      end
    end)
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
mix test test/klass_hero/shared/adapters/driven/events/pubsub_integration_event_publisher_test.exs
```

Expected: All tests pass.

- [ ] **Step 5: Run full test suite**

```bash
mix test
```

Expected: All tests pass. No regressions.

- [ ] **Step 6: Commit**

```bash
git add test/klass_hero/shared/adapters/driven/events/pubsub_integration_event_publisher_test.exs lib/klass_hero/shared/adapters/driven/events/pubsub_integration_event_publisher.ex
git commit -m "Add dual delivery for critical integration events in PubSubIntegrationEventPublisher (#325)"
```

---

## Chunk 6: Final Verification

### Task 12: Full Suite Verification and Precommit

- [ ] **Step 1: Run precommit checks**

```bash
mix precommit
```

Expected: Compilation with --warnings-as-errors, format, and full test suite all pass.

- [ ] **Step 2: Fix any warnings or test failures**

Address any issues found. Common issues:
- Unused aliases or imports
- Missing test setup for DB access
- Oban inline mode causing unexpected behavior in existing tests

- [ ] **Step 3: Final commit (if fixes needed)**

```bash
git add -A
git commit -m "Fix warnings and test issues from critical events implementation (#325)"
```

- [ ] **Step 4: Verify git status is clean**

```bash
git status
```

Expected: Working tree clean.
