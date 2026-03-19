# Seed Session Roster on Creation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a provider creates a session, automatically seed the roster with all children enrolled in that program.

**Architecture:** Async integration event subscriber reacts to `session_created` PubSub event, queries Enrollment context via ACL port for enrolled child IDs, bulk-inserts participation records with `Repo.insert_all` + ON CONFLICT DO NOTHING. A `roster_seeded` domain event notifies LiveViews for real-time UI updates.

**Tech Stack:** Elixir 1.20, Phoenix 1.8, Ecto, Phoenix.PubSub, DDD Ports & Adapters

**Spec:** `docs/superpowers/specs/2026-03-19-seed-session-roster-design.md`

**Skills:** @superpowers:test-driven-development, @idiomatic-elixir

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `lib/klass_hero/participation/domain/ports/for_resolving_enrolled_children.ex` | Behaviour contract for ACL |
| Create | `lib/klass_hero/participation/adapters/driven/enrollment_context/enrolled_children_resolver.ex` | ACL adapter — plucks child_ids from Enrollment |
| Create | `lib/klass_hero/participation/application/use_cases/seed_session_roster.ex` | Use case — orchestrates ACL query + bulk insert + event |
| Create | `lib/klass_hero/participation/adapters/driven/events/event_handlers/seed_session_roster_handler.ex` | Integration event handler — delegates to use case |
| Modify | `lib/klass_hero/participation/domain/ports/for_managing_participation.ex` | Add `seed_batch/2` callback |
| Modify | `lib/klass_hero/participation/adapters/driven/persistence/repositories/participation_repository.ex` | Implement `seed_batch/2` with `Repo.insert_all` + ON CONFLICT |
| Modify | `lib/klass_hero/participation/domain/events/participation_events.ex` | Add `roster_seeded/3` factory |
| Modify | `lib/klass_hero/participation/adapters/driven/events/event_handlers/promote_integration_events.ex` | Handle `roster_seeded` domain event |
| Modify | `lib/klass_hero/participation/domain/events/participation_integration_events.ex` | Add `roster_seeded/3` integration event factory |
| Modify | `lib/klass_hero/application.ex` | Register `roster_seeded` handlers in Participation DomainEventBus |
| Modify | `lib/klass_hero_web/live/provider/sessions_live.ex` | Handle `roster_seeded` in `handle_info` |
| Modify | `lib/klass_hero/participation.ex` | Add Boundary dep on `KlassHero.Enrollment` |
| Modify | `config/config.exs` | Wire `enrolled_children_resolver` adapter |
| Modify | `config/test.exs` | Wire `enrolled_children_resolver` for test env |
| Modify | `lib/klass_hero/application.ex` | Add `EventSubscriber` child for handler |
| Create | `test/klass_hero/participation/adapters/driven/enrollment_context/enrolled_children_resolver_test.exs` | ACL adapter test |
| Create | `test/klass_hero/participation/application/use_cases/seed_session_roster_test.exs` | Use case test |
| Create | `test/klass_hero/participation/adapters/driven/events/event_handlers/seed_session_roster_handler_test.exs` | Handler test |

---

### Task 1: Port — `ForResolvingEnrolledChildren`

**Files:**
- Create: `lib/klass_hero/participation/domain/ports/for_resolving_enrolled_children.ex`

- [ ] **Step 1: Create the port behaviour**

```elixir
defmodule KlassHero.Participation.Domain.Ports.ForResolvingEnrolledChildren do
  @moduledoc """
  Port for resolving enrolled children from the Enrollment context.

  ## Anti-Corruption Layer

  This port defines the contract for an ACL between the Participation
  and Enrollment bounded contexts. The Participation context needs
  child IDs for enrolled children when seeding session rosters.

  Only child IDs are returned — name resolution is handled separately
  by the existing ForResolvingChildInfo port.
  """

  @doc """
  Returns child IDs with active enrollments in a program.

  Returns an empty list if no enrollments exist.
  """
  @callback list_enrolled_child_ids(program_id :: String.t()) :: [String.t()]
end
```

- [ ] **Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation, zero warnings.

- [ ] **Step 3: Commit**

```bash
git add lib/klass_hero/participation/domain/ports/for_resolving_enrolled_children.ex
git commit -m "feat: add ForResolvingEnrolledChildren port (#471)"
```

---

### Task 2: ACL Adapter — `EnrolledChildrenResolver`

**Files:**
- Create: `lib/klass_hero/participation/adapters/driven/enrollment_context/enrolled_children_resolver.ex`
- Create: `test/klass_hero/participation/adapters/driven/enrollment_context/enrolled_children_resolver_test.exs`
- Modify: `lib/klass_hero/participation.ex` (Boundary deps)
- Modify: `config/config.exs`
- Modify: `config/test.exs`

- [ ] **Step 1: Write failing test — returns child IDs for enrolled children**

```elixir
defmodule KlassHero.Participation.Adapters.Driven.EnrollmentContext.EnrolledChildrenResolverTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Participation.Adapters.Driven.EnrollmentContext.EnrolledChildrenResolver

  describe "list_enrolled_child_ids/1" do
    test "returns child IDs for children with active enrollments in the program" do
      enrollment = insert(:enrollment_schema, status: "confirmed")

      result = EnrolledChildrenResolver.list_enrolled_child_ids(enrollment.program_id)

      assert result == [enrollment.child_id]
    end

    test "returns empty list when no enrollments exist" do
      result = EnrolledChildrenResolver.list_enrolled_child_ids(Ecto.UUID.generate())

      assert result == []
    end

    test "excludes children from other programs" do
      enrollment = insert(:enrollment_schema, status: "confirmed")
      _other_enrollment = insert(:enrollment_schema, status: "confirmed")

      result = EnrolledChildrenResolver.list_enrolled_child_ids(enrollment.program_id)

      assert result == [enrollment.child_id]
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/participation/adapters/driven/enrollment_context/enrolled_children_resolver_test.exs`
Expected: FAIL — module not found.

- [ ] **Step 3: Add Boundary dep and config before implementing**

In `lib/klass_hero/participation.ex`, add `KlassHero.Enrollment` to the Boundary deps list:

```elixir
  use Boundary,
    top_level?: true,
    deps: [KlassHero, KlassHero.Enrollment, KlassHero.Family, KlassHero.ProgramCatalog, KlassHero.Shared],
    exports: [Domain.Services.ParticipationCollection]
```

In `config/config.exs`, add to the `:participation` config block:

```elixir
  enrolled_children_resolver:
    KlassHero.Participation.Adapters.Driven.EnrollmentContext.EnrolledChildrenResolver
```

In `config/test.exs`, add to the `:participation` config block:

```elixir
  enrolled_children_resolver:
    KlassHero.Participation.Adapters.Driven.EnrollmentContext.EnrolledChildrenResolver
```

- [ ] **Step 4: Write minimal implementation**

```elixir
defmodule KlassHero.Participation.Adapters.Driven.EnrollmentContext.EnrolledChildrenResolver do
  @moduledoc """
  ACL adapter that resolves enrolled child IDs from the Enrollment context.

  ## Anti-Corruption Layer

  This adapter serves as an ACL between the Participation and Enrollment
  bounded contexts. It:

  1. Queries Enrollment for active enrollments via its public API
  2. Extracts only child_id values — no other enrollment data leaks

  ## Architecture

  ```
  SeedSessionRoster → ForResolvingEnrolledChildren Port → [THIS ADAPTER] → Enrollment Public API
       (use case)        (behaviour contract)              (data filter)     (owns enrollments)
  ```
  """

  @behaviour KlassHero.Participation.Domain.Ports.ForResolvingEnrolledChildren

  alias KlassHero.Enrollment

  @impl true
  def list_enrolled_child_ids(program_id) when is_binary(program_id) do
    program_id
    |> Enrollment.list_program_enrollments()
    |> Enum.map(& &1.child_id)
    |> Enum.uniq()
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/klass_hero/participation/adapters/driven/enrollment_context/enrolled_children_resolver_test.exs`
Expected: All 3 tests PASS.

- [ ] **Step 6: Run full compile check**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation.

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero/participation/adapters/driven/enrollment_context/enrolled_children_resolver.ex \
        test/klass_hero/participation/adapters/driven/enrollment_context/enrolled_children_resolver_test.exs \
        lib/klass_hero/participation.ex \
        config/config.exs config/test.exs
git commit -m "feat: add EnrolledChildrenResolver ACL adapter (#471)"
```

---

### Task 3: Repository — `seed_batch/2` with ON CONFLICT

**Files:**
- Modify: `lib/klass_hero/participation/domain/ports/for_managing_participation.ex`
- Modify: `lib/klass_hero/participation/adapters/driven/persistence/repositories/participation_repository.ex`
- Create: `test/klass_hero/participation/application/use_cases/seed_session_roster_test.exs` (partial — seed_batch integration test)

The existing `create_batch/1` uses `Multi` with individual inserts — it does NOT support ON CONFLICT. We need a new `seed_batch/2` that uses `Repo.insert_all` with `on_conflict: :nothing`.

- [ ] **Step 1: Write failing test for seed_batch**

Add to a new test file (we'll expand it in Task 4):

```elixir
defmodule KlassHero.Participation.Adapters.Driven.Persistence.Repositories.ParticipationRepository.SeedBatchTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Participation.Adapters.Driven.Persistence.Repositories.ParticipationRepository

  describe "seed_batch/2" do
    test "inserts participation records for given child IDs" do
      session = insert(:program_session_schema, status: "scheduled")
      child1 = insert(:child_schema)
      child2 = insert(:child_schema)

      {:ok, count} = ParticipationRepository.seed_batch(session.id, [child1.id, child2.id])

      assert count == 2
    end

    test "skips duplicates via ON CONFLICT DO NOTHING" do
      session = insert(:program_session_schema, status: "scheduled")
      child = insert(:child_schema)

      {:ok, 1} = ParticipationRepository.seed_batch(session.id, [child.id])
      {:ok, 0} = ParticipationRepository.seed_batch(session.id, [child.id])
    end

    test "returns {:ok, 0} for empty child ID list" do
      session = insert(:program_session_schema, status: "scheduled")

      assert {:ok, 0} = ParticipationRepository.seed_batch(session.id, [])
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/participation/adapters/driven/persistence/repositories/participation_repository/seed_batch_test.exs`
Expected: FAIL — `seed_batch/2` undefined.

- [ ] **Step 3: Add callback to port**

In `lib/klass_hero/participation/domain/ports/for_managing_participation.ex`, add before the closing `end`:

```elixir
  @doc """
  Bulk-seeds participation records for a session using insert_all with ON CONFLICT DO NOTHING.

  Returns `{:ok, count}` where count is the number of actually inserted records.
  Duplicates (existing session_id+child_id pairs) are silently skipped.
  """
  @callback seed_batch(session_id :: String.t(), child_ids :: [String.t()]) ::
              {:ok, non_neg_integer()}
```

- [ ] **Step 4: Implement seed_batch in repository**

In `lib/klass_hero/participation/adapters/driven/persistence/repositories/participation_repository.ex`, add:

```elixir
  @impl true
  def seed_batch(_session_id, []), do: {:ok, 0}

  def seed_batch(session_id, child_ids) when is_binary(session_id) and is_list(child_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    rows =
      Enum.map(child_ids, fn child_id ->
        %{
          id: Ecto.UUID.generate(),
          session_id: session_id,
          child_id: child_id,
          status: :registered,
          lock_version: 1,
          inserted_at: now,
          updated_at: now
        }
      end)

    {count, _} =
      Repo.insert_all(
        ParticipationRecordSchema,
        rows,
        on_conflict: :nothing,
        conflict_target: [:session_id, :child_id]
      )

    {:ok, count}
  end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/klass_hero/participation/adapters/driven/persistence/repositories/participation_repository/seed_batch_test.exs`
Expected: All 3 tests PASS.

- [ ] **Step 6: Run full compile check**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation.

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero/participation/domain/ports/for_managing_participation.ex \
        lib/klass_hero/participation/adapters/driven/persistence/repositories/participation_repository.ex \
        test/klass_hero/participation/adapters/driven/persistence/repositories/participation_repository/seed_batch_test.exs
git commit -m "feat: add seed_batch/2 with ON CONFLICT DO NOTHING (#471)"
```

---

### Task 4: Domain Event — `roster_seeded`

**Files:**
- Modify: `lib/klass_hero/participation/domain/events/participation_events.ex`
- Modify: `lib/klass_hero/participation/domain/events/participation_integration_events.ex`
- Modify: `lib/klass_hero/participation/adapters/driven/events/event_handlers/promote_integration_events.ex`
- Modify: `lib/klass_hero/application.ex` (DomainEventBus handler registration)

- [ ] **Step 1: Add `roster_seeded` factory to `ParticipationEvents`**

In `lib/klass_hero/participation/domain/events/participation_events.ex`, add after the `session_completed` function:

```elixir
  @doc "Creates a roster_seeded event."
  @spec roster_seeded(String.t(), String.t(), non_neg_integer(), keyword()) :: DomainEvent.t()
  def roster_seeded(session_id, program_id, count, opts \\ [])
      when is_binary(session_id) and is_binary(program_id) do
    payload = %{
      session_id: session_id,
      program_id: program_id,
      seeded_count: count
    }

    DomainEvent.new(:roster_seeded, session_id, @aggregate_type, payload, opts)
  end
```

- [ ] **Step 2: Add `roster_seeded` integration event factory**

In `lib/klass_hero/participation/domain/events/participation_integration_events.ex`, add after the `session_completed` section:

```elixir
  @typedoc "Payload for `:roster_seeded` events."
  @type roster_seeded_payload :: %{
          required(:session_id) => String.t(),
          required(:program_id) => String.t(),
          required(:seeded_count) => non_neg_integer()
        }
```

And the factory function:

```elixir
  # ---------------------------------------------------------------------------
  # roster_seeded (entity type: :session)
  # ---------------------------------------------------------------------------

  @doc """
  Creates a `roster_seeded` integration event.

  Published after participation records have been bulk-seeded for a new session.
  """
  def roster_seeded(session_id, %{program_id: _, seeded_count: _} = payload, opts \\ [])
      when is_binary(session_id) and byte_size(session_id) > 0 do
    base_payload = %{session_id: session_id}

    IntegrationEvent.new(
      :roster_seeded,
      @source_context,
      :session,
      session_id,
      Map.merge(payload, base_payload),
      opts
    )
  end
```

- [ ] **Step 3: Add handler clause in `PromoteIntegrationEvents`**

In `lib/klass_hero/participation/adapters/driven/events/event_handlers/promote_integration_events.ex`, add after the `session_completed` handler:

```elixir
  def handle(%DomainEvent{event_type: :roster_seeded} = event) do
    # Trigger: roster_seeded domain event dispatched from SeedSessionRoster use case
    # Why: downstream contexts may need to know roster is ready (e.g. notifications)
    # Outcome: best-effort publish; swallow failures since records are already persisted
    ParticipationIntegrationEvents.roster_seeded(event.aggregate_id, event.payload)
    |> IntegrationEventPublishing.publish_best_effort("roster_seeded",
      session_id: event.aggregate_id
    )
  end
```

- [ ] **Step 4: Register `roster_seeded` handlers in DomainEventBus**

In `lib/klass_hero/application.ex`, inside the `domain_event_buses/0` function, find the Participation context DomainEventBus entry (the one with `context: KlassHero.Participation`). Add these two handler entries to the handlers list, after the existing `behavioral_note_rejected` entries:

```elixir
           # roster_seeded: promote to integration event, then notify LiveViews
           {:roster_seeded,
            {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
             :handle}, priority: 10},
           {:roster_seeded,
            {KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews,
             :handle}},
```

Without this, `DomainEventBus.dispatch/2` in the use case will fire the `roster_seeded` event but no handlers will process it — the integration event will never be published and LiveViews will never be notified.

- [ ] **Step 5: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation.

- [ ] **Step 6: Handle `roster_seeded` in `SessionsLive`**

In `lib/klass_hero_web/live/provider/sessions_live.ex`, add `roster_seeded` to the event type guard in the existing `handle_info` clause (line 158):

Change:
```elixir
      when event_type in [:session_started, :session_completed, :session_created] do
```
To:
```elixir
      when event_type in [:session_started, :session_completed, :session_created, :roster_seeded] do
```

The existing `update_session_in_stream/2` logic already re-fetches the session — it will pick up the newly seeded participation records.

- [ ] **Step 7: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation.

- [ ] **Step 8: Commit**

```bash
git add lib/klass_hero/participation/domain/events/participation_events.ex \
        lib/klass_hero/participation/domain/events/participation_integration_events.ex \
        lib/klass_hero/participation/adapters/driven/events/event_handlers/promote_integration_events.ex \
        lib/klass_hero/application.ex \
        lib/klass_hero_web/live/provider/sessions_live.ex
git commit -m "feat: add roster_seeded domain and integration events (#471)"
```

---

### Task 5: Use Case — `SeedSessionRoster`

**Files:**
- Create: `lib/klass_hero/participation/application/use_cases/seed_session_roster.ex`
- Create: `test/klass_hero/participation/application/use_cases/seed_session_roster_test.exs`

- [ ] **Step 1: Write failing tests**

```elixir
defmodule KlassHero.Participation.Application.UseCases.SeedSessionRosterTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Participation.Application.UseCases.SeedSessionRoster
  alias KlassHero.Participation.Adapters.Driven.Persistence.Repositories.ParticipationRepository

  describe "execute/2" do
    test "creates participation records for enrolled children" do
      # Set up a program with an enrolled child
      enrollment = insert(:enrollment_schema, status: "confirmed")

      session =
        insert(:program_session_schema,
          program_id: enrollment.program_id,
          status: "scheduled"
        )

      assert :ok = SeedSessionRoster.execute(session.id, enrollment.program_id)

      records = ParticipationRepository.list_by_session(session.id)
      assert length(records) == 1
      assert hd(records).child_id == enrollment.child_id
      assert hd(records).status == :registered
    end

    test "is idempotent — running twice does not duplicate records" do
      enrollment = insert(:enrollment_schema, status: "confirmed")

      session =
        insert(:program_session_schema,
          program_id: enrollment.program_id,
          status: "scheduled"
        )

      assert :ok = SeedSessionRoster.execute(session.id, enrollment.program_id)
      assert :ok = SeedSessionRoster.execute(session.id, enrollment.program_id)

      records = ParticipationRepository.list_by_session(session.id)
      assert length(records) == 1
    end

    test "handles program with no enrollments gracefully" do
      session = insert(:program_session_schema, status: "scheduled")

      assert :ok = SeedSessionRoster.execute(session.id, session.program_id)

      records = ParticipationRepository.list_by_session(session.id)
      assert records == []
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/participation/application/use_cases/seed_session_roster_test.exs`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement the use case**

```elixir
defmodule KlassHero.Participation.Application.UseCases.SeedSessionRoster do
  @moduledoc """
  Use case for seeding a session roster with enrolled children.

  When a session is created, this use case queries the Enrollment context
  (via ACL) for active enrollments on the session's program, then bulk-inserts
  participation records with `:registered` status.

  ## Business Rules

  - All enrolled children are registered regardless of session max_capacity.
    Capacity is a scheduling/enrollment concern, not a roster gate.
  - Duplicate registrations are silently skipped (ON CONFLICT DO NOTHING).
  - Best-effort: failures are logged but do not propagate.

  ## Events Published

  - `roster_seeded` on successful seeding (even if count is 0)
  """

  alias KlassHero.Participation.Domain.Events.ParticipationEvents
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @context KlassHero.Participation

  @enrolled_children_resolver Application.compile_env!(:klass_hero, [
                                :participation,
                                :enrolled_children_resolver
                              ])
  @participation_repository Application.compile_env!(:klass_hero, [
                               :participation,
                               :participation_repository
                             ])

  @doc """
  Seeds a session roster with enrolled children from the program.

  ## Parameters

  - `session_id` - ID of the newly created session
  - `program_id` - ID of the program to resolve enrollments from

  ## Returns

  - `:ok` always (best-effort)
  """
  @spec execute(String.t(), String.t()) :: :ok
  def execute(session_id, program_id)
      when is_binary(session_id) and is_binary(program_id) do
    child_ids = @enrolled_children_resolver.list_enrolled_child_ids(program_id)

    # Trigger: max_capacity is intentionally not checked here
    # Why: all enrolled children should appear on the roster — capacity is an enrollment-time
    #      concern, not a per-session roster gate. A class of 25 enrolled kids should see all 25
    #      on every session, even if max_capacity is set lower for scheduling purposes.
    # Outcome: all child_ids are passed to seed_batch without filtering
    {:ok, count} = @participation_repository.seed_batch(session_id, child_ids)

    Logger.info("[SeedSessionRoster] Seeded roster",
      session_id: session_id,
      program_id: program_id,
      enrolled: length(child_ids),
      inserted: count,
      skipped: length(child_ids) - count
    )

    publish_event(session_id, program_id, count)

    :ok
  rescue
    error ->
      Logger.error(
        "[SeedSessionRoster] Failed to seed roster: #{Exception.message(error)}",
        session_id: session_id,
        program_id: program_id,
        stacktrace: Exception.format_stacktrace(__STACKTRACE__)
      )

      :ok
  end

  defp publish_event(session_id, program_id, count) do
    event = ParticipationEvents.roster_seeded(session_id, program_id, count)
    DomainEventBus.dispatch(@context, event)
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/participation/application/use_cases/seed_session_roster_test.exs`
Expected: All 3 tests PASS.

- [ ] **Step 5: Run full compile check**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation.

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/participation/application/use_cases/seed_session_roster.ex \
        test/klass_hero/participation/application/use_cases/seed_session_roster_test.exs
git commit -m "feat: add SeedSessionRoster use case (#471)"
```

---

### Task 6: Event Handler — `SeedSessionRosterHandler`

**Files:**
- Create: `lib/klass_hero/participation/adapters/driven/events/event_handlers/seed_session_roster_handler.ex`
- Create: `test/klass_hero/participation/adapters/driven/events/event_handlers/seed_session_roster_handler_test.exs`
- Modify: `lib/klass_hero/application.ex`

- [ ] **Step 1: Write failing tests**

```elixir
defmodule KlassHero.Participation.Adapters.Driven.Events.EventHandlers.SeedSessionRosterHandlerTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Participation.Adapters.Driven.Events.EventHandlers.SeedSessionRosterHandler
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  describe "handle_event/1" do
    test "delegates to SeedSessionRoster for session_created events" do
      # We test with real DB data — the handler should call through to the use case
      program = KlassHero.Factory.insert(:program_schema)

      session =
        KlassHero.Factory.insert(:program_session_schema,
          program_id: program.id,
          status: "scheduled"
        )

      event =
        IntegrationEvent.new(
          :session_created,
          :participation,
          :session,
          session.id,
          %{
            session_id: session.id,
            program_id: program.id,
            session_date: ~D[2026-03-20],
            start_time: ~T[09:00:00],
            end_time: ~T[10:00:00]
          }
        )

      assert :ok = SeedSessionRosterHandler.handle_event(event)
    end

    test "ignores non-session_created events" do
      event =
        IntegrationEvent.new(
          :session_started,
          :participation,
          :session,
          Ecto.UUID.generate(),
          %{session_id: Ecto.UUID.generate(), program_id: Ecto.UUID.generate()}
        )

      assert :ignore = SeedSessionRosterHandler.handle_event(event)
    end
  end

  describe "subscribed_events/0" do
    test "subscribes to session_created" do
      assert :session_created in SeedSessionRosterHandler.subscribed_events()
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/participation/adapters/driven/events/event_handlers/seed_session_roster_handler_test.exs`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement the handler**

```elixir
defmodule KlassHero.Participation.Adapters.Driven.Events.EventHandlers.SeedSessionRosterHandler do
  @moduledoc """
  Integration event handler that seeds session rosters when sessions are created.

  Subscribes to `session_created` integration events on PubSub and delegates
  to the SeedSessionRoster use case.

  ## Architecture

  ```
  PubSub "integration:participation:session_created"
    → EventSubscriber (shared GenServer)
    → [THIS HANDLER] handle_event/1
    → SeedSessionRoster.execute/2
  ```

  ## Error Strategy

  The use case is best-effort — errors are logged and swallowed.
  """

  @behaviour KlassHero.Shared.Domain.Ports.ForHandlingIntegrationEvents

  alias KlassHero.Participation.Application.UseCases.SeedSessionRoster
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  @impl true
  def subscribed_events, do: [:session_created]

  @impl true
  def handle_event(%IntegrationEvent{event_type: :session_created, payload: payload}) do
    SeedSessionRoster.execute(payload.session_id, payload.program_id)
  end

  def handle_event(_event), do: :ignore
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/participation/adapters/driven/events/event_handlers/seed_session_roster_handler_test.exs`
Expected: All 3 tests PASS.

- [ ] **Step 5: Wire into application supervision tree**

In `lib/klass_hero/application.ex`, inside the `integration_event_subscribers/0` function, add a new `Supervisor.child_spec` entry:

```elixir
      # Participation seeds session roster when a session is created
      Supervisor.child_spec(
        {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
         handler:
           KlassHero.Participation.Adapters.Driven.Events.EventHandlers.SeedSessionRosterHandler,
         topics: ["integration:participation:session_created"],
         message_tag: :integration_event,
         event_label: "Integration event"},
        id: :participation_seed_roster_subscriber
      ),
```

- [ ] **Step 6: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation.

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero/participation/adapters/driven/events/event_handlers/seed_session_roster_handler.ex \
        test/klass_hero/participation/adapters/driven/events/event_handlers/seed_session_roster_handler_test.exs \
        lib/klass_hero/application.ex
git commit -m "feat: add SeedSessionRosterHandler + wire into supervision tree (#471)"
```

---

### Task 7: Full Pre-commit Validation

- [ ] **Step 1: Run the full precommit suite**

Run: `mix precommit`
Expected: Compilation clean, format clean, all tests pass.

- [ ] **Step 2: Fix any issues discovered**

If warnings or test failures, fix them before proceeding.

- [ ] **Step 3: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: address precommit issues for roster seeding (#471)"
```
