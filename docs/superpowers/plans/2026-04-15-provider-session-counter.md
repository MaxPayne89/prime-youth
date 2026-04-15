# Provider Session Counter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Required skills:** `idiomatic-elixir` (activate for every Elixir file).
> **Tidewave MCP:** Use `project_eval` to verify module compilation, `get_docs` to check Ecto/Phoenix APIs, `execute_sql_query` to inspect table state, and `get_logs` to catch warnings after each task. The Phoenix dev server must be running.

**Goal:** Add an event-driven projection that tracks completed session counts per (provider, program) and surfaces the total on the Provider Overview Dashboard.

**Architecture:** CQRS read model — a `ProviderSessionStats` GenServer subscribes to `session_completed` integration events from the Participation context, maintains a denormalized `provider_session_stats` table, and publishes PubSub updates for real-time dashboard refresh.

**Tech Stack:** Elixir 1.20, Phoenix 1.8, LiveView 1.1, Ecto, Phoenix.PubSub, ExMachina

**Spec:** `docs/superpowers/specs/2026-04-15-provider-session-counter-design.md`

---

## File Structure

### New files (Provider context)

| File | Purpose |
|------|---------|
| `priv/repo/migrations/TIMESTAMP_create_provider_session_stats.exs` | Migration for read model table |
| `lib/klass_hero/provider/domain/read_models/session_stats.ex` | Read model DTO struct |
| `lib/klass_hero/provider/domain/ports/for_resolving_session_stats.ex` | Bootstrap ACL port |
| `lib/klass_hero/provider/domain/ports/for_querying_session_stats.ex` | Read repository port |
| `lib/klass_hero/provider/adapters/driven/persistence/schemas/session_stats_schema.ex` | Ecto schema for read table |
| `lib/klass_hero/provider/adapters/driven/persistence/repositories/session_stats_repository.ex` | Read repository |
| `lib/klass_hero/provider/adapters/driven/acl/participation_session_stats_acl.ex` | Bootstrap ACL adapter |
| `lib/klass_hero/provider/adapters/driven/projections/provider_session_stats.ex` | Projection GenServer |

### New test files

| File | Purpose |
|------|---------|
| `test/klass_hero/provider/adapters/driven/acl/participation_session_stats_acl_test.exs` | ACL unit test |
| `test/klass_hero/provider/adapters/driven/persistence/repositories/session_stats_repository_test.exs` | Repository unit test |
| `test/klass_hero/provider/adapters/driven/projections/provider_session_stats_test.exs` | Projection unit test |
| `test/klass_hero/participation/domain/events/participation_integration_events_test.exs` | Event enrichment test (may exist — append) |

### Modified files

| File | Change |
|------|--------|
| `lib/klass_hero/participation/domain/events/participation_events.ex` | Add `provider_id`, `program_title` to `session_completed` payload |
| `lib/klass_hero/participation/domain/events/participation_integration_events.ex` | Add `provider_id`, `program_title` to required payload keys + typespec |
| `lib/klass_hero/projection_supervisor.ex` | Switch to `:one_for_one`, add `ProviderSessionStats` child |
| `lib/klass_hero/provider.ex` | Add Boundary exports for new modules |
| `config/config.exs` | Wire new ports under `:provider` config key |
| `test/support/factory.ex` | Add `session_stats_schema_factory` |
| `lib/klass_hero_web/live/provider/dashboard_live.ex` | Wire session count into overview section |

---

### Task 1: Enrich `session_completed` Event with `provider_id` and `program_title`

**Files:**
- Modify: `lib/klass_hero/participation/domain/events/participation_events.ex:66-73`
- Modify: `lib/klass_hero/participation/domain/events/participation_integration_events.ex:237-263`
- Modify: `lib/klass_hero/participation/application/commands/complete_session.ex:79-81`
- Test: `test/klass_hero/participation/domain/events/participation_integration_events_test.exs`

- [ ] **Step 1: Write the failing test for enriched integration event**

Create or append to the integration events test file:

```elixir
# test/klass_hero/participation/domain/events/participation_integration_events_test.exs
defmodule KlassHero.Participation.Domain.Events.ParticipationIntegrationEventsTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Participation.Domain.Events.ParticipationIntegrationEvents

  describe "session_completed/3" do
    test "requires provider_id and program_title in payload" do
      event =
        ParticipationIntegrationEvents.session_completed("session-1", %{
          program_id: "prog-1",
          provider_id: "prov-1",
          program_title: "Art Class"
        })

      assert event.event_type == :session_completed
      assert event.payload.provider_id == "prov-1"
      assert event.payload.program_title == "Art Class"
      assert event.payload.program_id == "prog-1"
      assert event.payload.session_id == "session-1"
    end

    test "raises when provider_id is missing" do
      assert_raise ArgumentError, ~r/missing required payload keys/, fn ->
        ParticipationIntegrationEvents.session_completed("session-1", %{
          program_id: "prog-1"
        })
      end
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/participation/domain/events/participation_integration_events_test.exs -v`
Expected: FAIL — current `session_completed/3` only requires `program_id`, not `provider_id` or `program_title`.

- [ ] **Step 3: Update integration event builder to require `provider_id` and `program_title`**

In `lib/klass_hero/participation/domain/events/participation_integration_events.ex`, update the typespec and pattern match:

```elixir
  @typedoc "Payload for `:session_completed` events."
  @type session_completed_payload :: %{
          required(:session_id) => String.t(),
          required(:program_id) => String.t(),
          required(:provider_id) => String.t(),
          required(:program_title) => String.t(),
          optional(atom()) => term()
        }
```

Update the function head (line 239) to pattern match on the new required keys:

```elixir
  def session_completed(session_id, %{program_id: _, provider_id: _, program_title: _} = payload, opts)
      when is_binary(session_id) and byte_size(session_id) > 0 do
    base_payload = %{session_id: session_id}

    IntegrationEvent.new(
      :session_completed,
      @source_context,
      :session,
      session_id,
      Map.merge(payload, base_payload),
      opts
    )
  end
```

Update the error clause (line 253) to list the new required keys:

```elixir
  def session_completed(session_id, payload, _opts) when is_binary(session_id) and byte_size(session_id) > 0 do
    missing = [:program_id, :provider_id, :program_title] -- Map.keys(payload)

    raise ArgumentError,
          "session_completed missing required payload keys: #{inspect(missing)}"
  end
```

- [ ] **Step 4: Update domain event to carry `provider_id` and `program_title`**

The `CompleteSession` use case needs to resolve `provider_id` and pass `program_title` into the domain event so the promotion handler has them. Update `participation_events.ex`:

```elixir
  @doc "Creates a session_completed event."
  @spec session_completed(ProgramSession.t(), keyword()) :: DomainEvent.t()
  def session_completed(%ProgramSession{} = session, opts \\ []) do
    payload = %{
      session_id: session.id,
      program_id: session.program_id,
      completed_at: DateTime.utc_now()
    }

    # Merge any extra keys from opts[:extra_payload] (e.g., provider_id, program_title)
    extra = Keyword.get(opts, :extra_payload, %{})

    DomainEvent.new(:session_completed, session.id, @aggregate_type, Map.merge(payload, extra), opts)
  end
```

Update `CompleteSession.publish_session_completed/1` to resolve and include the extra fields:

```elixir
  @program_provider_resolver Application.compile_env!(:klass_hero, [
                               :participation,
                               :program_provider_resolver
                             ])

  defp publish_session_completed(session) do
    extra_payload = resolve_provider_details(session.program_id)
    event = ParticipationEvents.session_completed(session, extra_payload: extra_payload)
    DomainEventBus.dispatch(@context, event)
  end

  defp resolve_provider_details(program_id) do
    case @program_provider_resolver.resolve_provider_id(program_id) do
      {:ok, provider_id} ->
        program_title = resolve_program_title(program_id)
        %{provider_id: provider_id, program_title: program_title}

      {:error, _} ->
        %{}
    end
  end

  defp resolve_program_title(program_id) do
    case KlassHero.ProgramCatalog.get_programs_by_ids([program_id]) do
      [program] -> program.title
      _ -> "Unknown Program"
    end
  end
```

**Note:** Verify ProgramCatalog public API with Tidewave: `get_docs KlassHero.ProgramCatalog.get_programs_by_ids/1`

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/klass_hero/participation/domain/events/participation_integration_events_test.exs -v`
Expected: PASS

- [ ] **Step 6: Run full participation test suite**

Run: `mix test test/klass_hero/participation/ --max-failures 3`
Expected: PASS — existing tests should still work since the extra payload keys flow through `Map.merge`.

Use Tidewave to verify compilation: `project_eval "Code.ensure_compiled!(KlassHero.Participation.Application.Commands.CompleteSession)"`

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero/participation/ test/klass_hero/participation/
git commit -m "feat: enrich session_completed event with provider_id and program_title"
```

---

### Task 2: Create Migration and Ecto Schema for `provider_session_stats`

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_provider_session_stats.exs`
- Create: `lib/klass_hero/provider/adapters/driven/persistence/schemas/session_stats_schema.ex`

- [ ] **Step 1: Generate the migration**

Run: `mix ecto.gen.migration create_provider_session_stats`

- [ ] **Step 2: Write the migration**

```elixir
defmodule KlassHero.Repo.Migrations.CreateProviderSessionStats do
  use Ecto.Migration

  def change do
    create table(:provider_session_stats, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider_id, :binary_id, null: false
      add :program_id, :binary_id, null: false
      add :program_title, :string, null: false
      add :sessions_completed_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:provider_session_stats, [:provider_id, :program_id])
    create index(:provider_session_stats, [:provider_id])
  end
end
```

- [ ] **Step 3: Create the Ecto schema**

```elixir
# lib/klass_hero/provider/adapters/driven/persistence/schemas/session_stats_schema.ex
defmodule KlassHero.Provider.Adapters.Driven.Persistence.Schemas.SessionStatsSchema do
  @moduledoc """
  Ecto schema for the provider_session_stats read model table.

  Write-only from the projection's perspective, read-only from the repository's.
  No user-facing changesets — the projection controls all writes.
  """

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  schema "provider_session_stats" do
    field :provider_id, :binary_id
    field :program_id, :binary_id
    field :program_title, :string
    field :sessions_completed_count, :integer, default: 0

    timestamps()
  end
end
```

- [ ] **Step 4: Run migration and verify with Tidewave**

Run: `mix ecto.migrate`

Use Tidewave to verify: `execute_sql_query "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'provider_session_stats' ORDER BY ordinal_position"`

- [ ] **Step 5: Commit**

```bash
git add priv/repo/migrations/*create_provider_session_stats* lib/klass_hero/provider/adapters/driven/persistence/schemas/session_stats_schema.ex
git commit -m "feat: add provider_session_stats read model table and schema"
```

---

### Task 3: Create Read Model DTO and Read Repository Port

**Files:**
- Create: `lib/klass_hero/provider/domain/read_models/session_stats.ex`
- Create: `lib/klass_hero/provider/domain/ports/for_querying_session_stats.ex`

- [ ] **Step 1: Create the read model DTO**

```elixir
# lib/klass_hero/provider/domain/read_models/session_stats.ex
defmodule KlassHero.Provider.Domain.ReadModels.SessionStats do
  @moduledoc """
  Read-optimized DTO for provider session statistics.

  Lightweight struct for display — no business logic, no value objects.
  Populated from the denormalized provider_session_stats read table.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          provider_id: String.t(),
          program_id: String.t(),
          program_title: String.t(),
          sessions_completed_count: non_neg_integer(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @enforce_keys [:id, :provider_id, :program_id, :program_title, :sessions_completed_count]

  defstruct [
    :id,
    :provider_id,
    :program_id,
    :program_title,
    :inserted_at,
    :updated_at,
    sessions_completed_count: 0
  ]

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct!(__MODULE__, attrs)
  end
end
```

- [ ] **Step 2: Create the read repository port**

```elixir
# lib/klass_hero/provider/domain/ports/for_querying_session_stats.ex
defmodule KlassHero.Provider.Domain.Ports.ForQueryingSessionStats do
  @moduledoc """
  Read-only port for querying provider session statistics.

  Separated from the bootstrap ACL port. Read operations never mutate state.
  """

  alias KlassHero.Provider.Domain.ReadModels.SessionStats

  @doc """
  Lists all session stats for a provider, ordered by count descending.
  """
  @callback list_for_provider(provider_id :: binary()) :: [SessionStats.t()]

  @doc """
  Returns the total completed session count across all programs for a provider.
  """
  @callback get_total_count(provider_id :: binary()) :: non_neg_integer()
end
```

- [ ] **Step 3: Verify compilation with Tidewave**

Use Tidewave: `project_eval "Code.ensure_compiled!(KlassHero.Provider.Domain.ReadModels.SessionStats)"`
Use Tidewave: `project_eval "Code.ensure_compiled!(KlassHero.Provider.Domain.Ports.ForQueryingSessionStats)"`

- [ ] **Step 4: Commit**

```bash
git add lib/klass_hero/provider/domain/read_models/session_stats.ex lib/klass_hero/provider/domain/ports/for_querying_session_stats.ex
git commit -m "feat: add SessionStats read model DTO and query port"
```

---

### Task 4: Implement Read Repository (TDD)

**Files:**
- Create: `lib/klass_hero/provider/adapters/driven/persistence/repositories/session_stats_repository.ex`
- Create: `test/klass_hero/provider/adapters/driven/persistence/repositories/session_stats_repository_test.exs`
- Modify: `test/support/factory.ex` (add factory)
- Modify: `config/config.exs` (wire port)

- [ ] **Step 1: Add factory for session_stats_schema**

Append to `test/support/factory.ex` after the existing factories:

```elixir
  @doc """
  Factory for creating SessionStatsSchema Ecto schemas (CQRS read model).

  Used in tests that interact with the provider_session_stats read table.

  ## Examples

      schema = insert(:session_stats_schema)
      schema = insert(:session_stats_schema, sessions_completed_count: 5)
  """
  def session_stats_schema_factory do
    %KlassHero.Provider.Adapters.Driven.Persistence.Schemas.SessionStatsSchema{
      id: Ecto.UUID.generate(),
      provider_id: Ecto.UUID.generate(),
      program_id: Ecto.UUID.generate(),
      program_title: sequence(:session_stats_title, &"Program #{&1}"),
      sessions_completed_count: 0
    }
  end
```

Also add the alias at the top of the factory module alongside the other schema aliases.

- [ ] **Step 2: Write failing tests for the repository**

```elixir
# test/klass_hero/provider/adapters/driven/persistence/repositories/session_stats_repository_test.exs
defmodule KlassHero.Provider.Adapters.Driven.Persistence.Repositories.SessionStatsRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Provider.Adapters.Driven.Persistence.Repositories.SessionStatsRepository
  alias KlassHero.Provider.Domain.ReadModels.SessionStats

  describe "list_for_provider/1" do
    test "returns empty list when no stats exist" do
      assert [] == SessionStatsRepository.list_for_provider(Ecto.UUID.generate())
    end

    test "returns stats for the given provider ordered by count descending" do
      provider_id = Ecto.UUID.generate()

      insert(:session_stats_schema,
        provider_id: provider_id,
        program_title: "Art",
        sessions_completed_count: 3
      )

      insert(:session_stats_schema,
        provider_id: provider_id,
        program_title: "Music",
        sessions_completed_count: 7
      )

      # Different provider — should not appear
      insert(:session_stats_schema, sessions_completed_count: 10)

      result = SessionStatsRepository.list_for_provider(provider_id)

      assert [%SessionStats{program_title: "Music"}, %SessionStats{program_title: "Art"}] = result
      assert length(result) == 2
    end
  end

  describe "get_total_count/1" do
    test "returns 0 when no stats exist" do
      assert 0 == SessionStatsRepository.get_total_count(Ecto.UUID.generate())
    end

    test "returns sum of all session counts for the provider" do
      provider_id = Ecto.UUID.generate()

      insert(:session_stats_schema,
        provider_id: provider_id,
        sessions_completed_count: 3
      )

      insert(:session_stats_schema,
        provider_id: provider_id,
        sessions_completed_count: 7
      )

      assert 10 == SessionStatsRepository.get_total_count(provider_id)
    end
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `mix test test/klass_hero/provider/adapters/driven/persistence/repositories/session_stats_repository_test.exs -v`
Expected: FAIL — module does not exist yet.

- [ ] **Step 4: Implement the repository**

```elixir
# lib/klass_hero/provider/adapters/driven/persistence/repositories/session_stats_repository.ex
defmodule KlassHero.Provider.Adapters.Driven.Persistence.Repositories.SessionStatsRepository do
  @moduledoc """
  Read-side repository for the provider_session_stats denormalized table.

  Implements the ForQueryingSessionStats port. This repository only reads —
  the projection GenServer handles all writes.

  Returns lightweight SessionStats DTOs (no domain entities, no value objects).
  """

  @behaviour KlassHero.Provider.Domain.Ports.ForQueryingSessionStats

  import Ecto.Query

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.SessionStatsSchema
  alias KlassHero.Provider.Domain.ReadModels.SessionStats
  alias KlassHero.Repo

  @impl true
  def list_for_provider(provider_id) when is_binary(provider_id) do
    SessionStatsSchema
    |> where([s], s.provider_id == ^provider_id)
    |> order_by([s], desc: s.sessions_completed_count)
    |> Repo.all()
    |> Enum.map(&to_dto/1)
  end

  @impl true
  def get_total_count(provider_id) when is_binary(provider_id) do
    SessionStatsSchema
    |> where([s], s.provider_id == ^provider_id)
    |> select([s], coalesce(sum(s.sessions_completed_count), 0))
    |> Repo.one()
  end

  defp to_dto(%SessionStatsSchema{} = schema) do
    SessionStats.new(%{
      id: schema.id,
      provider_id: schema.provider_id,
      program_id: schema.program_id,
      program_title: schema.program_title,
      sessions_completed_count: schema.sessions_completed_count,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    })
  end
end
```

- [ ] **Step 5: Wire the port in config.exs**

Add to the `:provider` config block in `config/config.exs`:

```elixir
config :klass_hero, :provider,
  repo: KlassHero.Repo,
  for_storing_provider_profiles: ProviderProfileRepository,
  for_querying_provider_profiles: ProviderProfileRepository,
  for_storing_verification_documents: VerificationDocumentRepository,
  for_querying_verification_documents: VerificationDocumentRepository,
  for_storing_staff_members: StaffMemberRepository,
  for_querying_staff_members: StaffMemberRepository,
  for_storing_program_staff_assignments: ProgramStaffAssignmentRepository,
  for_querying_program_staff_assignments: ProgramStaffAssignmentRepository,
  for_querying_session_stats: SessionStatsRepository,
  for_resolving_session_stats: ParticipationSessionStatsACL
```

Add the alias to the config aliases block (search for existing Provider aliases).

- [ ] **Step 6: Run tests to verify they pass**

Run: `mix test test/klass_hero/provider/adapters/driven/persistence/repositories/session_stats_repository_test.exs -v`
Expected: PASS

Use Tidewave: `get_logs --tail 20 --grep warning` to check for compilation warnings.

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero/provider/adapters/driven/persistence/repositories/session_stats_repository.ex test/klass_hero/provider/adapters/driven/persistence/repositories/session_stats_repository_test.exs test/support/factory.ex config/config.exs
git commit -m "feat: add SessionStats read repository with query port"
```

---

### Task 5: Create Bootstrap ACL Port and Adapter (TDD)

**Files:**
- Create: `lib/klass_hero/provider/domain/ports/for_resolving_session_stats.ex`
- Create: `lib/klass_hero/provider/adapters/driven/acl/participation_session_stats_acl.ex`
- Create: `test/klass_hero/provider/adapters/driven/acl/participation_session_stats_acl_test.exs`

- [ ] **Step 1: Create the bootstrap ACL port**

```elixir
# lib/klass_hero/provider/domain/ports/for_resolving_session_stats.ex
defmodule KlassHero.Provider.Domain.Ports.ForResolvingSessionStats do
  @moduledoc """
  Port for resolving initial session completion counts from the Participation context.

  Used exclusively during projection bootstrap. Cross-context query is acceptable
  here because it runs once on startup, not on every request.
  """

  @doc """
  Returns completed session counts grouped by (provider_id, program_id).
  """
  @callback list_completed_session_counts() ::
              {:ok,
               [
                 %{
                   provider_id: String.t(),
                   program_id: String.t(),
                   program_title: String.t(),
                   sessions_completed_count: non_neg_integer()
                 }
               ]}
              | {:error, term()}
end
```

- [ ] **Step 2: Write failing test for the ACL**

```elixir
# test/klass_hero/provider/adapters/driven/acl/participation_session_stats_acl_test.exs
defmodule KlassHero.Provider.Adapters.Driven.ACL.ParticipationSessionStatsACLTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Provider.Adapters.Driven.ACL.ParticipationSessionStatsACL

  describe "list_completed_session_counts/0" do
    test "returns empty list when no completed sessions exist" do
      assert {:ok, []} = ParticipationSessionStatsACL.list_completed_session_counts()
    end

    test "counts completed sessions grouped by provider and program" do
      # Create a program owned by a provider
      provider_schema = insert(:provider_profile_schema)
      program_schema = insert(:program_schema, provider_id: provider_schema.id)

      # Create completed sessions for this program
      insert(:program_session_schema,
        program_id: program_schema.id,
        status: "completed"
      )

      insert(:program_session_schema,
        program_id: program_schema.id,
        status: "completed"
      )

      # Create a non-completed session — should NOT be counted
      insert(:program_session_schema,
        program_id: program_schema.id,
        status: "scheduled"
      )

      {:ok, results} = ParticipationSessionStatsACL.list_completed_session_counts()

      assert [result] = results
      assert result.provider_id == provider_schema.id
      assert result.program_id == program_schema.id
      assert result.program_title == program_schema.title
      assert result.sessions_completed_count == 2
    end

    test "groups by program across multiple providers" do
      provider_a = insert(:provider_profile_schema)
      provider_b = insert(:provider_profile_schema)
      program_a = insert(:program_schema, provider_id: provider_a.id, title: "Art")
      program_b = insert(:program_schema, provider_id: provider_b.id, title: "Music")

      insert(:program_session_schema, program_id: program_a.id, status: "completed")
      insert(:program_session_schema, program_id: program_b.id, status: "completed")
      insert(:program_session_schema, program_id: program_b.id, status: "completed")

      {:ok, results} = ParticipationSessionStatsACL.list_completed_session_counts()

      by_provider = Map.new(results, &{&1.provider_id, &1})
      assert by_provider[provider_a.id].sessions_completed_count == 1
      assert by_provider[provider_b.id].sessions_completed_count == 2
    end
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `mix test test/klass_hero/provider/adapters/driven/acl/participation_session_stats_acl_test.exs -v`
Expected: FAIL — module does not exist.

- [ ] **Step 4: Check if `provider_profile_schema` factory exists**

Use Tidewave: `project_eval "KlassHero.Factory.__info__(:functions) |> Enum.filter(fn {name, _} -> name |> to_string() |> String.contains?(\"provider_profile_schema\") end)"`

If missing, add a `provider_profile_schema_factory` to `test/support/factory.ex` using the `ProviderProfileSchema` directly (like the existing `program_schema_factory` pattern).

- [ ] **Step 5: Implement the ACL adapter**

```elixir
# lib/klass_hero/provider/adapters/driven/acl/participation_session_stats_acl.ex
defmodule KlassHero.Provider.Adapters.Driven.ACL.ParticipationSessionStatsACL do
  @moduledoc """
  Anti-corruption layer for resolving session completion counts from Participation.

  Cross-context bootstrap query: joins Participation's `program_sessions` with
  Program Catalog's `programs` to compute counts grouped by (provider_id, program_id).

  Used exclusively during ProviderSessionStats projection bootstrap.
  """

  @behaviour KlassHero.Provider.Domain.Ports.ForResolvingSessionStats

  import Ecto.Query

  alias KlassHero.Repo

  require Logger

  @impl true
  def list_completed_session_counts do
    results =
      from(s in "program_sessions",
        join: p in "programs",
        on: s.program_id == p.id,
        where: s.status == "completed",
        group_by: [p.provider_id, p.id, p.title],
        select: %{
          provider_id: type(p.provider_id, :binary_id),
          program_id: type(p.id, :binary_id),
          program_title: p.title,
          sessions_completed_count: count(s.id)
        }
      )
      |> Repo.all()

    Logger.debug("[ParticipationSessionStatsACL] Bootstrap query returned #{length(results)} rows")

    {:ok, results}
  rescue
    error ->
      Logger.error("[ParticipationSessionStatsACL] Bootstrap query failed",
        error: Exception.message(error)
      )

      {:error, :bootstrap_query_failed}
  end
end
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `mix test test/klass_hero/provider/adapters/driven/acl/participation_session_stats_acl_test.exs -v`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero/provider/domain/ports/for_resolving_session_stats.ex lib/klass_hero/provider/adapters/driven/acl/participation_session_stats_acl.ex test/klass_hero/provider/adapters/driven/acl/participation_session_stats_acl_test.exs test/support/factory.ex
git commit -m "feat: add bootstrap ACL for session completion counts"
```

---

### Task 6: Implement Projection GenServer (TDD)

**Files:**
- Create: `lib/klass_hero/provider/adapters/driven/projections/provider_session_stats.ex`
- Create: `test/klass_hero/provider/adapters/driven/projections/provider_session_stats_test.exs`

- [ ] **Step 1: Write failing test for live event handling**

```elixir
# test/klass_hero/provider/adapters/driven/projections/provider_session_stats_test.exs
defmodule KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionStatsTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.SessionStatsSchema
  alias KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionStats
  alias KlassHero.Repo
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  defp build_session_completed_event(attrs) do
    %IntegrationEvent{
      event_id: Ecto.UUID.generate(),
      event_type: :session_completed,
      source_context: :participation,
      entity_type: :session,
      entity_id: attrs[:session_id] || Ecto.UUID.generate(),
      occurred_at: DateTime.utc_now(),
      payload: %{
        session_id: attrs[:session_id] || Ecto.UUID.generate(),
        program_id: attrs[:program_id] || Ecto.UUID.generate(),
        provider_id: attrs[:provider_id] || Ecto.UUID.generate(),
        program_title: attrs[:program_title] || "Test Program"
      },
      metadata: %{},
      version: 1
    }
  end

  describe "handle_info/2 session_completed event" do
    test "inserts a new row on first event for a provider+program" do
      # Start the projection without bootstrap (no ACL data)
      {:ok, pid} = ProviderSessionStats.start_link(name: :"test_projection_#{System.unique_integer()}", skip_bootstrap: true)

      provider_id = Ecto.UUID.generate()
      program_id = Ecto.UUID.generate()

      event = build_session_completed_event(
        provider_id: provider_id,
        program_id: program_id,
        program_title: "Art Class"
      )

      send(pid, {:integration_event, event})

      # Give the GenServer time to process
      :sys.get_state(pid)

      stats = Repo.all(from s in SessionStatsSchema, where: s.provider_id == ^provider_id)

      assert [stat] = stats
      assert stat.program_id == program_id
      assert stat.program_title == "Art Class"
      assert stat.sessions_completed_count == 1
    end

    test "increments count on subsequent events for same provider+program" do
      {:ok, pid} = ProviderSessionStats.start_link(name: :"test_projection_#{System.unique_integer()}", skip_bootstrap: true)

      provider_id = Ecto.UUID.generate()
      program_id = Ecto.UUID.generate()

      event = build_session_completed_event(
        provider_id: provider_id,
        program_id: program_id,
        program_title: "Art Class"
      )

      send(pid, {:integration_event, event})
      :sys.get_state(pid)

      send(pid, {:integration_event, event})
      :sys.get_state(pid)

      send(pid, {:integration_event, event})
      :sys.get_state(pid)

      stat = Repo.one!(from s in SessionStatsSchema,
        where: s.provider_id == ^provider_id and s.program_id == ^program_id
      )

      assert stat.sessions_completed_count == 3
    end

    test "tracks separate counts per program" do
      {:ok, pid} = ProviderSessionStats.start_link(name: :"test_projection_#{System.unique_integer()}", skip_bootstrap: true)

      provider_id = Ecto.UUID.generate()
      program_a = Ecto.UUID.generate()
      program_b = Ecto.UUID.generate()

      send(pid, {:integration_event, build_session_completed_event(
        provider_id: provider_id,
        program_id: program_a,
        program_title: "Art"
      )})

      send(pid, {:integration_event, build_session_completed_event(
        provider_id: provider_id,
        program_id: program_b,
        program_title: "Music"
      )})

      send(pid, {:integration_event, build_session_completed_event(
        provider_id: provider_id,
        program_id: program_b,
        program_title: "Music"
      )})

      :sys.get_state(pid)

      stats =
        SessionStatsSchema
        |> where([s], s.provider_id == ^provider_id)
        |> order_by([s], asc: s.program_title)
        |> Repo.all()

      assert [art, music] = stats
      assert art.sessions_completed_count == 1
      assert music.sessions_completed_count == 2
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/provider/adapters/driven/projections/provider_session_stats_test.exs -v`
Expected: FAIL — module does not exist.

- [ ] **Step 3: Implement the projection GenServer**

```elixir
# lib/klass_hero/provider/adapters/driven/projections/provider_session_stats.ex
defmodule KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionStats do
  @moduledoc """
  Event-driven projection maintaining the `provider_session_stats` read table.

  Subscribes to `session_completed` integration events from the Participation
  context and tracks per-(provider, program) completion counts.

  ## Startup Behavior

  On init:
  1. Subscribes to the session_completed PubSub topic
  2. Bootstraps from Participation source data via ACL
  3. Live events atomically increment counts

  ## Counter Accuracy

  Bootstrap computes the full accurate count from source. Live events increment
  atomically using SQL `sessions_completed_count + 1`. On crash/restart, the
  supervisor triggers a fresh bootstrap that recomputes from source.
  """

  use GenServer

  import Ecto.Query

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.SessionStatsSchema
  alias KlassHero.Repo
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  require Logger

  @session_completed_topic "integration:participation:session_completed"

  @acl Application.compile_env!(:klass_hero, [:provider, :for_resolving_session_stats])

  # Client API

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    unless Keyword.get(opts, :skip_bootstrap, false) do
      Phoenix.PubSub.subscribe(KlassHero.PubSub, @session_completed_topic)
    end

    skip_bootstrap = Keyword.get(opts, :skip_bootstrap, false)

    if skip_bootstrap do
      {:ok, %{bootstrapped: true}}
    else
      {:ok, %{bootstrapped: false}, {:continue, :bootstrap}}
    end
  end

  @impl true
  def handle_continue(:bootstrap, state) do
    attempt_bootstrap(state)
  end

  @impl true
  def handle_info(:retry_bootstrap, state) do
    {:noreply, state, {:continue, :bootstrap}}
  end

  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :session_completed} = event}, state) do
    %{provider_id: provider_id, program_id: program_id} = event.payload
    program_title = Map.get(event.payload, :program_title, "Unknown Program")

    Logger.debug("ProviderSessionStats projecting session_completed",
      provider_id: provider_id,
      program_id: program_id,
      event_id: event.event_id
    )

    upsert_session_count(provider_id, program_id, program_title)
    notify_dashboard(provider_id)

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("ProviderSessionStats received unexpected message",
      message: inspect(msg, limit: 200)
    )

    {:noreply, state}
  end

  # Private Functions

  defp attempt_bootstrap(state) do
    case @acl.list_completed_session_counts() do
      {:ok, counts} ->
        bootstrap_counts(counts)
        Logger.info("ProviderSessionStats projection started", count: length(counts))
        {:noreply, %{state | bootstrapped: true}}

      {:error, reason} ->
        retry_count = Map.get(state, :retry_count, 0) + 1

        if retry_count > 3 do
          raise "ProviderSessionStats bootstrap failed after 3 retries: #{inspect(reason)}"
        else
          Logger.error("ProviderSessionStats: bootstrap failed, scheduling retry",
            reason: inspect(reason),
            retry_count: retry_count
          )

          Process.send_after(self(), :retry_bootstrap, 5_000 * retry_count)
          {:noreply, Map.put(state, :retry_count, retry_count)}
        end
    end
  end

  defp bootstrap_counts([]), do: :ok

  defp bootstrap_counts(counts) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      Enum.map(counts, fn row ->
        %{
          id: Ecto.UUID.generate(),
          provider_id: row.provider_id,
          program_id: row.program_id,
          program_title: row.program_title,
          sessions_completed_count: row.sessions_completed_count,
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(SessionStatsSchema, entries,
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:provider_id, :program_id]
    )
  end

  defp upsert_session_count(provider_id, program_id, program_title) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs = %{
      id: Ecto.UUID.generate(),
      provider_id: provider_id,
      program_id: program_id,
      program_title: program_title,
      sessions_completed_count: 1,
      inserted_at: now,
      updated_at: now
    }

    %SessionStatsSchema{}
    |> Ecto.Changeset.change(attrs)
    |> Repo.insert!(
      on_conflict:
        from(s in SessionStatsSchema,
          update: [
            set: [
              sessions_completed_count: fragment("? + 1", s.sessions_completed_count),
              program_title: ^program_title,
              updated_at: ^now
            ]
          ]
        ),
      conflict_target: [:provider_id, :program_id]
    )
  end

  defp notify_dashboard(provider_id) do
    Phoenix.PubSub.broadcast(
      KlassHero.PubSub,
      "provider:#{provider_id}:stats_updated",
      :session_stats_updated
    )
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/provider/adapters/driven/projections/provider_session_stats_test.exs -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/provider/adapters/driven/projections/provider_session_stats.ex test/klass_hero/provider/adapters/driven/projections/provider_session_stats_test.exs
git commit -m "feat: add ProviderSessionStats projection GenServer"
```

---

### Task 7: Refactor ProjectionSupervisor to `:one_for_one`

**Files:**
- Modify: `lib/klass_hero/projection_supervisor.ex`

- [ ] **Step 1: Update the supervisor strategy and add new child**

```elixir
defmodule KlassHero.ProjectionSupervisor do
  @moduledoc """
  Supervises all CQRS projection GenServers under an isolated subtree.

  Uses `:one_for_one` strategy — each projection crashes and restarts
  independently. Projections that depend on others during bootstrap
  (e.g., ProgramListings → VerifiedProviders) handle unavailability
  via their own retry logic.
  """

  use Supervisor

  alias KlassHero.Messaging.Adapters.Driven.Projections.ConversationSummaries
  alias KlassHero.ProgramCatalog.Adapters.Driven.Projections.ProgramListings
  alias KlassHero.ProgramCatalog.Adapters.Driven.Projections.VerifiedProviders
  alias KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionStats

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      VerifiedProviders,
      ProgramListings,
      ConversationSummaries,
      ProviderSessionStats
    ]

    Supervisor.init(children, strategy: :one_for_one, max_restarts: 10, max_seconds: 60)
  end
end
```

- [ ] **Step 2: Verify existing tests still pass**

Run: `mix test --max-failures 5`
Expected: PASS — projections are disabled in test config (`start_projections: false`), so the supervision strategy change has no test impact.

Use Tidewave to verify the supervisor is healthy in dev: `project_eval "Supervisor.which_children(KlassHero.ProjectionSupervisor)"`

- [ ] **Step 3: Commit**

```bash
git add lib/klass_hero/projection_supervisor.ex
git commit -m "refactor: switch ProjectionSupervisor to one_for_one strategy

Independent supervision prevents cascading restarts between unrelated
projections. Adds ProviderSessionStats as fourth projection child."
```

---

### Task 8: Update Boundary Exports for Provider Context

**Files:**
- Modify: `lib/klass_hero/provider.ex`

- [ ] **Step 1: Add new module exports to Boundary config**

In `lib/klass_hero/provider.ex`, add to the `exports` list:

```elixir
  use Boundary,
    top_level?: true,
    deps: [KlassHero, KlassHero.Shared],
    exports: [
      Domain.Models.ProviderProfile,
      Domain.Models.StaffMember,
      Domain.Models.VerificationDocument,
      Domain.Models.ProgramStaffAssignment,
      Domain.ReadModels.SessionStats,
      Adapters.Driven.Persistence.ChangeProviderProfile,
      Adapters.Driven.Persistence.ChangeStaffMember,
      # Pragmatic export: Backpex admin operates directly on Ecto schemas
      Adapters.Driven.Persistence.Schemas.ProviderProfileSchema,
      Adapters.Driven.Persistence.Schemas.StaffMemberSchema
    ]
```

- [ ] **Step 2: Verify compilation with Tidewave**

Use Tidewave: `project_eval "Code.ensure_compiled!(KlassHero.Provider)"`

Run: `mix compile --warnings-as-errors`
Expected: No warnings.

- [ ] **Step 3: Commit**

```bash
git add lib/klass_hero/provider.ex
git commit -m "chore: export SessionStats read model from Provider boundary"
```

---

### Task 9: Wire Session Count into Provider Dashboard (TDD)

**Files:**
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex`

- [ ] **Step 1: Update mount to assign initial session count**

In the `mount` function, after the existing assigns (around line 116), add:

```elixir
|> assign(total_sessions_completed: 0)
```

- [ ] **Step 2: Update `handle_params(:overview)` to load and subscribe**

```elixir
  @impl true
  def handle_params(_params, _uri, %{assigns: %{live_action: :overview}} = socket) do
    provider = socket.assigns.current_scope.provider

    docs = fetch_verification_docs(provider.id)

    verification_status =
      ProviderPresenter.verification_status_from_docs(provider.verified, docs)

    business = %{socket.assigns.business | verification_status: verification_status}

    total_sessions = fetch_total_sessions_completed(provider.id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(KlassHero.PubSub, "provider:#{provider.id}:stats_updated")
    end

    {:noreply,
     socket
     |> assign(business: business)
     |> assign(total_sessions_completed: total_sessions)}
  end
```

Add the private helper:

```elixir
  @session_stats_repo Application.compile_env!(:klass_hero, [:provider, :for_querying_session_stats])

  defp fetch_total_sessions_completed(provider_id) do
    @session_stats_repo.get_total_count(provider_id)
  end
```

- [ ] **Step 3: Add `handle_info` for real-time stats updates**

```elixir
  @impl true
  def handle_info(:session_stats_updated, socket) do
    provider = socket.assigns.current_scope.provider
    total_sessions = fetch_total_sessions_completed(provider.id)

    {:noreply, assign(socket, total_sessions_completed: total_sessions)}
  end
```

- [ ] **Step 4: Update `overview_section` template to show session count**

Replace the commented-out stats section (lines 1295-1328) with a single stat card:

```heex
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
      <.provider_stat_card
        label={gettext("Sessions Completed")}
        value={to_string(@total_sessions_completed)}
        icon="hero-check-badge-mini"
        icon_bg="bg-green-100"
        icon_color="text-green-600"
      />
    </div>
```

Keep the TODO comment for other future stat cards removed.

- [ ] **Step 5: Verify compilation and run existing dashboard tests**

Run: `mix compile --warnings-as-errors`
Run: `mix test test/klass_hero_web/live/provider/ --max-failures 3`
Expected: PASS

Use Tidewave to verify the page loads: `project_eval "KlassHeroWeb.Provider.DashboardLive.__info__(:functions)"`

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero_web/live/provider/dashboard_live.ex
git commit -m "feat: display session counter on provider overview dashboard"
```

---

### Task 10: Final Verification

- [ ] **Step 1: Run full precommit**

Run: `mix precommit`
Expected: PASS — compile with warnings-as-errors, format, lint_typography, full test suite.

- [ ] **Step 2: Verify with Tidewave end-to-end**

Use Tidewave to check the projection table state:
`execute_sql_query "SELECT * FROM provider_session_stats LIMIT 10"`

Use Tidewave to check for warnings in logs:
`get_logs --tail 50 --grep warning`

Use Tidewave to verify the projection is running:
`project_eval "Supervisor.which_children(KlassHero.ProjectionSupervisor) |> Enum.map(fn {id, _, _, _} -> id end)"`

- [ ] **Step 3: Run credo**

Run: `mix credo --strict`
Expected: No new issues.

- [ ] **Step 4: Commit any formatting/credo fixes**

```bash
git add -A
git commit -m "chore: formatting and credo fixes"
```

(Skip if nothing to commit.)

- [ ] **Step 5: Push**

```bash
git push -u origin feat/372-session-counter
```
