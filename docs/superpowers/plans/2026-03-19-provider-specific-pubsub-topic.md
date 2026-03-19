# Provider-Specific PubSub Topic Routing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route Participation domain events to provider-specific PubSub topics so SessionsLive receives only events for its provider, eliminating client-side filtering.

**Architecture:** ACL port in Participation resolves `program_id → provider_id` via ProgramCatalog public API. The Participation NotifyLiveViews handler publishes to both the generic topic (backward compat) and a provider-specific topic. Event payloads for attendance events are enriched with `program_id`.

**Tech Stack:** Elixir, Phoenix PubSub, DDD Ports & Adapters

**Spec:** `docs/superpowers/specs/2026-03-19-provider-specific-pubsub-topic-design.md`

**Skills:** Use `idiomatic-elixir` for all Elixir code. Follow `superpowers:test-driven-development` strictly — red/green/refactor for every change.

---

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `lib/klass_hero/participation/domain/ports/for_resolving_program_provider.ex` | Behaviour contract for resolving provider_id from program_id |
| Create | `lib/klass_hero/participation/adapters/driven/program_catalog_context/program_provider_resolver.ex` | ACL adapter calling ProgramCatalog |
| Create | `test/klass_hero/participation/adapters/driven/program_catalog_context/program_provider_resolver_test.exs` | Adapter integration test |
| Modify | `config/config.exs:148-155` | Add `program_provider_resolver` key |
| Modify | `config/test.exs:34-40` | Add `program_provider_resolver` key |
| Modify | `lib/klass_hero/participation/domain/events/participation_events.ex:76-115` | Add `/2` arities accepting session for attendance events |
| Modify | `lib/klass_hero/participation/application/use_cases/shared.ex:43-67` | Fetch session, pass to event factory |
| Modify | `lib/klass_hero/participation/application/use_cases/complete_session.ex:67-83` | Pass session to `child_marked_absent` event factory |
| Modify | `lib/klass_hero/participation/application/use_cases/bulk_check_in.ex:69-91` | Fetch session, pass to `child_checked_in` event factory |
| Modify | `lib/klass_hero/participation/adapters/driven/events/event_handlers/notify_live_views.ex` | Replace delegation with dual-topic publishing via ACL |
| Create | `test/klass_hero/participation/adapters/driven/events/event_handlers/notify_live_views_test.exs` | Replace existing test with provider-specific topic tests |
| Modify | `lib/klass_hero_web/live/provider/sessions_live.ex:28-41,152-195` | Subscribe to provider topic, simplify handle_info |

---

### Task 1: ACL Port — ForResolvingProgramProvider

**Files:**
- Create: `lib/klass_hero/participation/domain/ports/for_resolving_program_provider.ex`

- [ ] **Step 1: Create the port behaviour**

Follow the pattern from `lib/klass_hero/participation/domain/ports/for_resolving_child_info.ex`.

```elixir
defmodule KlassHero.Participation.Domain.Ports.ForResolvingProgramProvider do
  @moduledoc """
  Port for resolving program ownership from ProgramCatalog context.

  ## Anti-Corruption Layer

  This port defines the contract for an anti-corruption layer between the
  Participation bounded context and the ProgramCatalog bounded context.

  The Participation context needs provider IDs to route domain events to
  provider-specific PubSub topics. This port isolates the cross-context
  lookup behind a behaviour contract.

  ## Error Mapping

  ProgramCatalog errors are mapped to Participation semantics:
  - Program not found → `:program_not_found`
  """

  @doc """
  Resolves the provider ID that owns the given program.

  Returns `{:ok, provider_id}` or `{:error, :program_not_found}`.
  """
  @callback resolve_provider_id(program_id :: binary()) ::
              {:ok, binary()} | {:error, :program_not_found}
end
```

- [ ] **Step 2: Verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compilation succeeds with zero warnings.

- [ ] **Step 3: Commit**

```
git add lib/klass_hero/participation/domain/ports/for_resolving_program_provider.ex
git commit -m "feat: add ForResolvingProgramProvider ACL port (#464)"
```

---

### Task 2: ACL Adapter — ProgramProviderResolver

**Files:**
- Create: `test/klass_hero/participation/adapters/driven/program_catalog_context/program_provider_resolver_test.exs`
- Create: `lib/klass_hero/participation/adapters/driven/program_catalog_context/program_provider_resolver.ex`
- Modify: `config/config.exs:148-155`
- Modify: `config/test.exs:34-40`

- [ ] **Step 1: Write the failing tests**

Follow the pattern from `test/klass_hero/participation/adapters/driven/family_context/child_info_resolver_test.exs`.

```elixir
defmodule KlassHero.Participation.Adapters.Driven.ProgramCatalogContext.ProgramProviderResolverTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Participation.Adapters.Driven.ProgramCatalogContext.ProgramProviderResolver

  describe "resolve_provider_id/1" do
    test "returns provider_id for an existing program" do
      provider = KlassHero.Factory.insert(:provider_profile_schema)
      program = KlassHero.Factory.insert(:program_schema, provider_id: provider.id)

      assert {:ok, provider_id} = ProgramProviderResolver.resolve_provider_id(program.id)
      assert provider_id == provider.id
    end

    test "returns :program_not_found when program does not exist" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :program_not_found} =
               ProgramProviderResolver.resolve_provider_id(non_existent_id)
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/participation/adapters/driven/program_catalog_context/program_provider_resolver_test.exs`
Expected: FAIL — module `ProgramProviderResolver` not found.

- [ ] **Step 3: Write the adapter**

```elixir
defmodule KlassHero.Participation.Adapters.Driven.ProgramCatalogContext.ProgramProviderResolver do
  @moduledoc """
  Adapter for resolving program ownership from ProgramCatalog context.

  ## Anti-Corruption Layer

  This adapter serves as an anti-corruption layer between the Participation and
  ProgramCatalog bounded contexts. It resolves which provider owns a given program.

  ```
  NotifyLiveViews Handler → ForResolvingProgramProvider Port → [THIS ADAPTER] → ProgramCatalog Public API
       (needs provider_id)    (behaviour contract)              (ACL lookup)      (owns Program model)
  ```

  ## Error Mapping

  ProgramCatalog errors are mapped to Participation semantics:
  - Empty result from `get_programs_by_ids/1` → `:program_not_found`
  """

  @behaviour KlassHero.Participation.Domain.Ports.ForResolvingProgramProvider

  alias KlassHero.ProgramCatalog

  @impl true
  def resolve_provider_id(program_id) when is_binary(program_id) do
    case ProgramCatalog.get_programs_by_ids([program_id]) do
      [program] ->
        {:ok, program.provider_id}

      [] ->
        {:error, :program_not_found}
    end
  end
end
```

- [ ] **Step 4: Wire config**

Add to `config/config.exs` under `:participation` (after `behavioral_note_repository` line):

```elixir
  program_provider_resolver:
    KlassHero.Participation.Adapters.Driven.ProgramCatalogContext.ProgramProviderResolver
```

Add same to `config/test.exs` under `:participation`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/klass_hero/participation/adapters/driven/program_catalog_context/program_provider_resolver_test.exs`
Expected: 2 tests, 0 failures.

- [ ] **Step 6: Commit**

```
git add lib/klass_hero/participation/adapters/driven/program_catalog_context/program_provider_resolver.ex \
        test/klass_hero/participation/adapters/driven/program_catalog_context/program_provider_resolver_test.exs \
        config/config.exs config/test.exs
git commit -m "feat: add ProgramProviderResolver ACL adapter (#464)"
```

---

### Task 3: Enrich Attendance Event Payloads with program_id

**Files:**
- Modify: `lib/klass_hero/participation/domain/events/participation_events.ex:76-115`
- Existing test: `test/klass_hero/participation/adapters/driven/events/event_handlers/promote_integration_events_test.exs` (may need update if it asserts on payload shape)

- [ ] **Step 1: Write failing tests for new /2 arities**

Add tests to the existing event test file or create a unit test for the event factory. The key assertion: calling `child_checked_in(record, session)` produces a payload with `program_id`.

Create a small unit test file:

```elixir
# In test/klass_hero/participation/domain/events/participation_events_payload_test.exs

defmodule KlassHero.Participation.Domain.Events.ParticipationEventsPayloadTest do
  use ExUnit.Case, async: true

  alias KlassHero.Participation.Domain.Events.ParticipationEvents
  alias KlassHero.Participation.Domain.Models.ParticipationRecord
  alias KlassHero.Participation.Domain.Models.ProgramSession

  @program_id Ecto.UUID.generate()

  defp build_record do
    %ParticipationRecord{
      id: Ecto.UUID.generate(),
      session_id: Ecto.UUID.generate(),
      child_id: Ecto.UUID.generate(),
      status: :checked_in,
      check_in_by: Ecto.UUID.generate(),
      check_in_at: DateTime.utc_now(),
      check_in_notes: nil
    }
  end

  defp build_session do
    %ProgramSession{
      id: Ecto.UUID.generate(),
      program_id: @program_id,
      session_date: Date.utc_today(),
      start_time: ~T[09:00:00],
      end_time: ~T[12:00:00],
      status: :in_progress
    }
  end

  describe "child_checked_in/2" do
    test "includes program_id from session in payload" do
      record = build_record()
      session = build_session()

      event = ParticipationEvents.child_checked_in(record, session)

      assert event.payload.program_id == @program_id
    end

    test "preserves all existing payload fields" do
      record = build_record()
      session = build_session()

      event = ParticipationEvents.child_checked_in(record, session)

      assert event.payload.record_id == record.id
      assert event.payload.session_id == record.session_id
      assert event.payload.child_id == record.child_id
    end
  end

  describe "child_checked_out/2" do
    test "includes program_id from session in payload" do
      record = %{build_record() | status: :checked_out, check_out_by: Ecto.UUID.generate(), check_out_at: DateTime.utc_now()}
      session = build_session()

      event = ParticipationEvents.child_checked_out(record, session)

      assert event.payload.program_id == @program_id
    end
  end

  describe "child_marked_absent/2" do
    test "includes program_id from session in payload" do
      record = %{build_record() | status: :absent}
      session = build_session()

      event = ParticipationEvents.child_marked_absent(record, session)

      assert event.payload.program_id == @program_id
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/participation/domain/events/participation_events_payload_test.exs`
Expected: FAIL — `child_checked_in/2` is undefined.

- [ ] **Step 3: Add /2 arities to ParticipationEvents**

In `lib/klass_hero/participation/domain/events/participation_events.ex`, add new function clauses. The existing `/1` arities with `opts \\ []` default create both `/1` and `/2` arities, so we need to remove the defaults and use explicit pattern matching on the second argument's type.

For each of `child_checked_in`, `child_checked_out`, `child_marked_absent`:

1. Remove `opts \\ []` default from existing function
2. Add explicit `/1` clause that delegates to `/2` with empty opts
3. Add `/2` clause with `when is_list(opts)` guard for backward compat
4. Add `/2` clause pattern matching on `%ProgramSession{}` for the new enriched variant

Example for `child_checked_in`:

```elixir
@doc "Creates a child_checked_in event."
@spec child_checked_in(ParticipationRecord.t()) :: DomainEvent.t()
def child_checked_in(%ParticipationRecord{} = record) do
  child_checked_in(record, [])
end

@spec child_checked_in(ParticipationRecord.t(), keyword()) :: DomainEvent.t()
def child_checked_in(%ParticipationRecord{} = record, opts) when is_list(opts) do
  payload = %{
    record_id: record.id,
    session_id: record.session_id,
    child_id: record.child_id,
    checked_in_by: record.check_in_by,
    checked_in_at: record.check_in_at,
    notes: record.check_in_notes
  }

  DomainEvent.new(:child_checked_in, record.id, @aggregate_type, payload, opts)
end

@doc "Creates a child_checked_in event with program_id from the session."
@spec child_checked_in(ParticipationRecord.t(), ProgramSession.t()) :: DomainEvent.t()
def child_checked_in(%ParticipationRecord{} = record, %ProgramSession{} = session) do
  payload = %{
    record_id: record.id,
    session_id: record.session_id,
    child_id: record.child_id,
    checked_in_by: record.check_in_by,
    checked_in_at: record.check_in_at,
    notes: record.check_in_notes,
    program_id: session.program_id
  }

  DomainEvent.new(:child_checked_in, record.id, @aggregate_type, payload, [])
end
```

Apply same pattern for `child_checked_out` and `child_marked_absent`. Add `alias KlassHero.Participation.Domain.Models.ProgramSession` to the module.

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/participation/domain/events/participation_events_payload_test.exs`
Expected: 4 tests, 0 failures.

- [ ] **Step 5: Run full test suite to verify no regressions**

Run: `mix test`
Expected: All tests pass. Existing callers using `/1` still work.

- [ ] **Step 6: Commit**

```
git add lib/klass_hero/participation/domain/events/participation_events.ex \
        test/klass_hero/participation/domain/events/participation_events_payload_test.exs
git commit -m "feat: enrich attendance event payloads with program_id (#464)"
```

---

### Task 4: Update Use Cases to Pass Session to Event Factory

**Files:**
- Modify: `lib/klass_hero/participation/application/use_cases/shared.ex:43-67`
- Modify: `lib/klass_hero/participation/application/use_cases/complete_session.ex:67-83`
- Modify: `lib/klass_hero/participation/application/use_cases/bulk_check_in.ex:69-91`
- Existing tests: `test/klass_hero/participation/application/use_cases/record_check_in_test.exs`, `record_check_out_test.exs`, `complete_session_test.exs`, `bulk_check_in_test.exs`

- [ ] **Step 1: Update `Shared.run_attendance_action`**

The `event_fn` type changes from `(record -> event)` to `(record, session -> event)`. The function needs to fetch the session by looking up the record's `session_id`.

```elixir
# Change the event_fn type
@type event_fn :: (ParticipationRecord.t(), ProgramSession.t() -> DomainEvent.t())

@session_repository Application.compile_env!(:klass_hero, [:participation, :session_repository])

def run_attendance_action(record_id, actor_id, notes, domain_fn, event_fn) do
  notes = normalize_notes(notes)

  with {:ok, record} <- @participation_repository.get_by_id(record_id),
       {:ok, updated} <- domain_fn.(record, actor_id, notes),
       {:ok, persisted} <- @participation_repository.update(updated),
       # Trigger: need session to include program_id in attendance event payloads
       # Why: provider-specific PubSub routing requires program_id → provider_id resolution
       # Outcome: session fetched and passed to event factory for payload enrichment
       {:ok, session} <- @session_repository.get_by_id(persisted.session_id) do
    event = event_fn.(persisted, session)
    DomainEventBus.dispatch(@context, event)
    {:ok, persisted}
  end
end
```

Add `alias KlassHero.Participation.Domain.Models.ProgramSession` to the module.

- [ ] **Step 2: Update callers of `run_attendance_action`**

In `RecordCheckIn` (line 51):
```elixir
&ParticipationEvents.child_checked_in/2
```

In `RecordCheckOut` (line 51):
```elixir
&ParticipationEvents.child_checked_out/2
```

- [ ] **Step 3: Update `CompleteSession.mark_absent`**

The `mark_absent/1` private function already has access to `session_id` via the parent `execute/1`. Refactor to pass the session through:

```elixir
# Change execute/1 to pass session to mark_remaining_as_absent
def execute(session_id) when is_binary(session_id) do
  with {:ok, session} <- @session_repository.get_by_id(session_id),
       {:ok, completed} <- ProgramSession.complete(session),
       {:ok, persisted} <- @session_repository.update(completed),
       :ok <- mark_remaining_as_absent(persisted) do
    publish_session_completed(persisted)
    {:ok, persisted}
  end
end

defp mark_remaining_as_absent(session) do
  session.id
  |> @participation_repository.list_by_session()
  |> Enum.filter(&(&1.status == :registered))
  |> Enum.each(&mark_absent(&1, session))

  :ok
end

defp mark_absent(%ParticipationRecord{} = record, session) do
  with {:ok, absent} <- ParticipationRecord.mark_absent(record),
       {:ok, persisted} <- @participation_repository.update(absent) do
    publish_child_absent(persisted, session)
    :ok
  end
end

defp publish_child_absent(record, session) do
  event = ParticipationEvents.child_marked_absent(record, session)
  DomainEventBus.dispatch(@context, event)
end
```

- [ ] **Step 4: Update `BulkCheckIn.check_in_record`**

The bulk check-in use case needs the session. Since all records in a bulk check-in belong to the same session, fetch it once and pass through:

```elixir
def execute(%{record_ids: record_ids, checked_in_by: checked_in_by} = params) do
  notes = Map.get(params, :notes)
  session_id = Map.get(params, :session_id)

  # Trigger: bulk check-in may need session for enriched event payloads
  # Why: provider-specific PubSub routing requires program_id from session
  # Outcome: fetch session once, pass to all individual check-in operations
  session = fetch_session(session_id, record_ids)

  record_ids
  |> Enum.map(&check_in_record(&1, checked_in_by, notes, session))
  |> Enum.reduce(%{successful: [], failed: []}, &categorize_result/2)
  |> then(fn result ->
    %{
      successful: Enum.reverse(result.successful),
      failed: Enum.reverse(result.failed)
    }
  end)
end
```

**Note:** Check how `BulkCheckIn` is called — does it receive `session_id` in params? If not, fetch the session from the first record's `session_id` after fetching it. The simplest approach: fetch session from the first record inside `check_in_record`, or restructure. Given the implementation, the cleanest approach is to fetch the session from the first record's `session_id`:

```elixir
defp check_in_record(record_id, checked_in_by, notes, session) do
  with {:ok, record} <- @participation_repository.get_by_id(record_id),
       {:ok, checked_in} <- ParticipationRecord.check_in(record, checked_in_by, notes),
       {:ok, persisted} <- @participation_repository.update(checked_in) do
    # Trigger: session may be nil if not resolved yet
    # Why: first record fetch resolves session_id; subsequent records reuse it
    # Outcome: fetch session lazily on first record, pass to event factory
    session = session || fetch_session_for_record(persisted)
    publish_event(persisted, session)
    {:ok, persisted}
  else
    {:error, reason} -> {:error, record_id, reason}
  end
end
```

Actually, this gets complicated with the reduce. Simpler approach — just fetch the session inside `check_in_record` for each record. The extra fetches are negligible (same session_id hits DB cache):

```elixir
defp check_in_record(record_id, checked_in_by, notes) do
  with {:ok, record} <- @participation_repository.get_by_id(record_id),
       {:ok, checked_in} <- ParticipationRecord.check_in(record, checked_in_by, notes),
       {:ok, persisted} <- @participation_repository.update(checked_in),
       {:ok, session} <- @session_repository.get_by_id(persisted.session_id) do
    publish_event(persisted, session)
    {:ok, persisted}
  else
    {:error, reason} -> {:error, record_id, reason}
  end
end

defp publish_event(record, session) do
  event = ParticipationEvents.child_checked_in(record, session)
  DomainEventBus.dispatch(@context, event)
end
```

Add `@session_repository` module attribute to `BulkCheckIn`.

- [ ] **Step 5: Run existing tests to verify no regressions**

Run: `mix test test/klass_hero/participation/application/use_cases/record_check_in_test.exs test/klass_hero/participation/application/use_cases/record_check_out_test.exs test/klass_hero/participation/application/use_cases/complete_session_test.exs test/klass_hero/participation/application/use_cases/bulk_check_in_test.exs`
Expected: All existing tests pass. The event payloads now include `program_id` but existing assertions should still hold (they assert on specific fields, not exact payload shape).

- [ ] **Step 6: Run full test suite**

Run: `mix test`
Expected: All tests pass.

- [ ] **Step 7: Commit**

```
git add lib/klass_hero/participation/application/use_cases/shared.ex \
        lib/klass_hero/participation/application/use_cases/complete_session.ex \
        lib/klass_hero/participation/application/use_cases/bulk_check_in.ex \
        lib/klass_hero/participation/application/use_cases/record_check_in.ex \
        lib/klass_hero/participation/application/use_cases/record_check_out.ex
git commit -m "feat: pass session to attendance event factories for payload enrichment (#464)"
```

---

### Task 5: NotifyLiveViews Handler — Dual-Topic Publishing

**Files:**
- Modify: `lib/klass_hero/participation/adapters/driven/events/event_handlers/notify_live_views.ex`
- Modify: `test/klass_hero/participation/adapters/driven/events/event_handlers/notify_live_views_test.exs`

- [ ] **Step 1: Write failing tests**

Replace the existing test file. **Note:** `safe_publish` uses the configured publisher (`TestEventPublisher` in tests), not real PubSub. Use `assert_event_published` for verifying events were published. For provider-specific topic routing, test that the handler resolves `provider_id` correctly and doesn't crash on missing programs. The actual PubSub topic correctness is verified end-to-end in SessionsLive tests (Task 6).

```elixir
defmodule KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViewsTest do
  use KlassHero.DataCase, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews
  alias KlassHero.Shared.Domain.Events.DomainEvent

  setup do
    setup_test_events()
    :ok
  end

  describe "handle/1 — events with valid program_id" do
    test "returns :ok and publishes event for session_created" do
      provider = KlassHero.Factory.insert(:provider_profile_schema)
      program = KlassHero.Factory.insert(:program_schema, provider_id: provider.id)
      session_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:session_created, session_id, :participation, %{
          session_id: session_id,
          program_id: program.id
        })

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:session_created)
    end

    test "returns :ok and publishes event for child_checked_in" do
      provider = KlassHero.Factory.insert(:provider_profile_schema)
      program = KlassHero.Factory.insert(:program_schema, provider_id: provider.id)

      event =
        DomainEvent.new(:child_checked_in, Ecto.UUID.generate(), :participation, %{
          record_id: Ecto.UUID.generate(),
          session_id: Ecto.UUID.generate(),
          child_id: Ecto.UUID.generate(),
          program_id: program.id
        })

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:child_checked_in)
    end
  end

  describe "handle/1 — graceful degradation" do
    test "returns :ok when program_id does not exist (provider-specific publish skipped)" do
      event =
        DomainEvent.new(:session_started, Ecto.UUID.generate(), :participation, %{
          session_id: Ecto.UUID.generate(),
          program_id: Ecto.UUID.generate()
        })

      assert :ok = NotifyLiveViews.handle(event)
      # Generic topic publish still happened
      assert_event_published(:session_started)
    end

    test "returns :ok when payload has no program_id" do
      event =
        DomainEvent.new(:session_created, Ecto.UUID.generate(), :participation, %{
          session_id: Ecto.UUID.generate()
        })

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:session_created)
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/participation/adapters/driven/events/event_handlers/notify_live_views_test.exs`
Expected: FAIL — current handler only publishes to generic topic.

- [ ] **Step 3: Implement dual-topic publishing**

Replace the delegation in `notify_live_views.ex`:

```elixir
defmodule KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews do
  @moduledoc """
  Routes Participation domain events to PubSub topics for LiveView real-time updates.

  Publishes each event to two topics:
  1. Generic topic (`participation:event_type`) — for context-wide subscribers
  2. Provider-specific topic (`participation:provider:provider_id`) — for provider-scoped LiveViews

  Provider ID is resolved via the ForResolvingProgramProvider ACL port.
  If resolution fails, the provider-specific publish is skipped (best-effort).
  """

  alias KlassHero.Shared.Adapters.Driven.Events.EventHandlers.NotifyLiveViews,
    as: SharedNotifyLiveViews

  alias KlassHero.Shared.Domain.Events.DomainEvent

  require Logger

  @program_provider_resolver Application.compile_env!(
                                :klass_hero,
                                [:participation, :program_provider_resolver]
                              )

  @doc "Handles a domain event by publishing to generic and provider-specific topics."
  @spec handle(DomainEvent.t()) :: :ok
  def handle(%DomainEvent{} = event) do
    # Trigger: every participation event needs both generic and provider-specific routing
    # Why: generic topic serves context-wide subscribers (ParticipationLive, ParticipationHistoryLive);
    #      provider-specific topic serves SessionsLive without client-side filtering
    # Outcome: two publishes per event, both best-effort
    generic_topic = SharedNotifyLiveViews.derive_topic(event)
    SharedNotifyLiveViews.safe_publish(event, generic_topic)

    publish_to_provider_topic(event)

    :ok
  end

  defp publish_to_provider_topic(%DomainEvent{payload: payload} = event) do
    case Map.fetch(payload, :program_id) do
      {:ok, program_id} ->
        resolve_and_publish(event, program_id)

      :error ->
        # Trigger: event payload has no program_id
        # Why: some events may not have been enriched yet
        # Outcome: skip provider-specific publish, log for visibility
        Logger.debug(
          "[Participation.NotifyLiveViews] Skipping provider topic — no program_id in payload",
          event_type: event.event_type
        )
    end
  end

  defp resolve_and_publish(event, program_id) do
    case @program_provider_resolver.resolve_provider_id(program_id) do
      {:ok, provider_id} ->
        provider_topic = "participation:provider:#{provider_id}"
        SharedNotifyLiveViews.safe_publish(event, provider_topic)

      {:error, :program_not_found} ->
        # Trigger: program_id in event payload doesn't match any program
        # Why: possible data inconsistency or recently deleted program
        # Outcome: log warning, skip provider-specific publish (generic still went through)
        Logger.warning(
          "[Participation.NotifyLiveViews] Could not resolve provider for program",
          program_id: program_id,
          event_type: event.event_type
        )
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/participation/adapters/driven/events/event_handlers/notify_live_views_test.exs`
Expected: All tests pass.

- [ ] **Step 5: Run full test suite**

Run: `mix test`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```
git add lib/klass_hero/participation/adapters/driven/events/event_handlers/notify_live_views.ex \
        test/klass_hero/participation/adapters/driven/events/event_handlers/notify_live_views_test.exs
git commit -m "feat: publish participation events to provider-specific PubSub topics (#464)"
```

---

### Task 6: SessionsLive — Subscribe to Provider Topic

**Files:**
- Modify: `lib/klass_hero_web/live/provider/sessions_live.ex:28-41,152-195`

- [ ] **Step 1: Update subscription in mount**

Replace the four generic topic subscriptions (lines 28-41) with one provider-specific subscription:

```elixir
if connected?(socket) do
  # Trigger: subscribing to provider-specific topic
  # Why: events are already routed to provider's topic by NotifyLiveViews handler;
  #      no client-side filtering needed
  # Outcome: LiveView receives only events for this provider's programs
  Phoenix.PubSub.subscribe(
    KlassHero.PubSub,
    "participation:provider:#{provider_id}"
  )
end
```

- [ ] **Step 2: Simplify handle_info for session events**

Replace the existing handle_info (lines 152-180) — remove MapSet filtering:

```elixir
@impl true
def handle_info(
      {:domain_event,
       %KlassHero.Shared.Domain.Events.DomainEvent{
         event_type: event_type,
         aggregate_id: session_id,
         payload: payload
       }},
      socket
    )
    when event_type in [:session_started, :session_completed, :session_created] do
  # Trigger: session_created events may be for a date not currently viewed
  # Why: stream only shows sessions for selected_date; wrong-date sessions would pollute the view
  # Outcome: for session_created, check date; start/complete are for existing stream items
  if event_type == :session_created and
       Map.get(payload, :session_date) != socket.assigns.selected_date do
    {:noreply, socket}
  else
    {:noreply, update_session_in_stream(socket, session_id)}
  end
end
```

- [ ] **Step 3: Simplify handle_info for child_checked_in**

Replace the existing handler (lines 183-195) — no need for `update_session_in_stream_if_owned`:

```elixir
@impl true
def handle_info(
      {:domain_event,
       %KlassHero.Shared.Domain.Events.DomainEvent{
         event_type: :child_checked_in,
         payload: %{session_id: session_id}
       }},
      socket
    ) do
  {:noreply, update_session_in_stream(socket, session_id)}
end
```

- [ ] **Step 4: Remove `update_session_in_stream_if_owned` helper**

Delete the `update_session_in_stream_if_owned/2` function (lines 351-363) — it's no longer needed.

- [ ] **Step 5: Run existing SessionsLive tests**

Run: `mix test test/klass_hero_web/live/provider/sessions_live_test.exs` (if it exists)
Expected: Tests pass. If no LiveView test exists yet, verify with `mix compile --warnings-as-errors`.

- [ ] **Step 6: Run full test suite**

Run: `mix test`
Expected: All tests pass.

- [ ] **Step 7: Commit**

```
git add lib/klass_hero_web/live/provider/sessions_live.ex
git commit -m "feat: subscribe SessionsLive to provider-specific PubSub topic (#464)"
```

---

### Task 7: Final Verification

- [ ] **Step 1: Run precommit checks**

Run: `mix precommit`
Expected: Compiles with zero warnings, formats cleanly, all tests pass.

- [ ] **Step 2: Verify no unused code**

Check that `update_session_in_stream_if_owned` is fully removed and no dead references remain.

Run: `grep -r "update_session_in_stream_if_owned" lib/ test/`
Expected: No results.

- [ ] **Step 3: Commit any cleanup**

If any cleanup was needed, commit it.
