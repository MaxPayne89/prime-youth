# Per-Session View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the per-session view in the provider dashboard (issue #373) by introducing a new `ProviderSessionDetails` projection in the Provider context, surfaced through a new port, a thin use case, and a `sessions_modal` component.

**Architecture:** Event-driven projection maintained by a supervised GenServer in the Provider context, subscribing to Participation + Provider integration events. Bootstraps on every boot via a cross-table SELECT. Read is a single-table query on `provider_session_details`. UI reuses `participation_status` with a new `:cancelled` variant.

**Tech Stack:** Elixir 1.20, Phoenix 1.8, LiveView 1.1, Ecto + PostgreSQL, Phoenix.PubSub, Oban (indirect), Tidewave MCP (for all interactive verification), Tailwind CSS.

**Spec:** `docs/superpowers/specs/2026-04-18-per-session-view-projection-design.md`

**Branch:** `feat/373-per-session-view`

---

## Execution Directives (apply to every task)

1. **Tidewave MCP is the default tool for all interactive verification.** Prefer `project_eval`, `execute_sql_query`, `get_logs`, `get_ecto_schemas`, `get_docs`, `get_source_location` over bash/iex. When the plan says "verify" or "inspect", that means Tidewave.
2. **Strict TDD red-green.** Every implementation task begins with a failing test that's *verified* to fail. Implementation follows to make it pass — and only that test. No speculative code.
3. **Elixir conventions** — apply `idiomatic-elixir` (pattern matching, pipes, guards, no `String.to_atom/1` on input, struct access not bracket access) for every `.ex`/`.exs` file. Apply `elixir-ecto-patterns` for migrations, schemas, queries.
4. **Commit after every green test** — the project uses conventional commits (`feat:`, `fix:`, `refactor:`, `test:`, `chore:`, `docs:`). Commit messages should not reference Claude.
5. **Run `mix precommit`** at the end of a task cluster (the plan marks explicit checkpoints). The full suite must pass before marking done.
6. **Before opening a PR** — run `/review-architecture` (boundary-checker + architecture-reviewer) and resolve findings. Expected flag: bootstrap cross-context reads; mitigation is per-context helpers.

---

## Pre-flight Facts (resolved during plan writing)

- `integration:participation:session_cancelled` **does not exist**. Must be added: factory in `ParticipationIntegrationEvents`, promotion handler in `PromoteIntegrationEvents`, and emission from the domain when a session is cancelled.
- `ProjectionSupervisor` lives at `lib/klass_hero/projection_supervisor.ex` — a centralized supervisor for all projections. The new projection is added to its `children` list.
- `session_created` payload carries `{session_id, program_id, session_date, start_time, end_time}` — **not** `program_title` or `provider_id`. The projection handler resolves these via a read of the `programs` table inside the Provider repo, same as the bootstrap query. This is the one acknowledged cross-context read, symmetric with bootstrap.
- Staff integration events (`staff_assigned_to_program`, `staff_unassigned_from_program`) carry `staff_member_id`, `provider_id`, `program_id`, `staff_user_id`, `assigned_at`/`unassigned_at` — **not** `staff_member_name`. Handler reads the name from `staff_members` (same Provider context — in-context, fine).

---

## File Structure Map

**New files:**

| Path | Responsibility |
|---|---|
| `lib/klass_hero/provider/domain/read_models/session_detail.ex` | DTO returned to the web layer |
| `lib/klass_hero/provider/domain/ports/for_querying_session_details.ex` | Port behaviour |
| `lib/klass_hero/provider/adapters/driven/persistence/schemas/provider_session_detail_schema.ex` | Ecto schema for `provider_session_details` |
| `lib/klass_hero/provider/adapters/driven/persistence/mappers/provider_session_detail_mapper.ex` | Schema ↔ DTO |
| `lib/klass_hero/provider/adapters/driven/persistence/repositories/session_details_repository.ex` | Implements the port |
| `lib/klass_hero/provider/adapters/driven/projections/provider_session_details.ex` | Projection GenServer |
| `lib/klass_hero/provider/application/queries/list_program_sessions.ex` | Use case |
| `priv/repo/migrations/<ts>_create_provider_session_details.exs` | Migration |
| `test/klass_hero/provider/adapters/driven/projections/provider_session_details_test.exs` | Unit tests for handlers |
| `test/klass_hero/provider/adapters/driven/projections/provider_session_details_bootstrap_test.exs` | Bootstrap + rebuild tests |
| `test/klass_hero/provider/adapters/driven/persistence/repositories/session_details_repository_test.exs` | Repository tests |
| `test/klass_hero/provider/application/queries/list_program_sessions_test.exs` | Use-case test |

**Modified files:**

| Path | Change |
|---|---|
| `lib/klass_hero/participation/domain/events/participation_integration_events.ex` | Add `session_cancelled/3` factory |
| `lib/klass_hero/participation/adapters/driving/events/event_handlers/promote_integration_events.ex` | Add `session_cancelled` handler clause |
| `lib/klass_hero/participation/...` (cancel use case) | Emit `session_cancelled` domain event on cancellation — find actual file via Task 1 |
| `lib/klass_hero/projection_supervisor.ex` | Add `ProviderSessionDetails` to children |
| `config/config.exs` | Wire `for_querying_session_details` under `:provider` key |
| `config/test.exs` | (if needed) bind test adapter |
| `lib/klass_hero_web/components/participation_components.ex` | Extend `participation_status` with `:cancelled` clause |
| `lib/klass_hero_web/components/provider_components.ex` | Add `sessions_modal/1`; add Sessions button to `programs_table` Actions |
| `lib/klass_hero_web/live/provider_live/dashboard_live.ex` | Add `:sessions_modal` assign + `view_sessions`/`close_sessions` handlers |
| `priv/gettext/de/LC_MESSAGES/default.po` | German translations for new strings |
| `priv/gettext/default.pot` | Regenerate via `mix gettext.extract` |

---

## Task 0: Preflight — Tidewave & Branch Check

**Goal:** Confirm the dev env is usable before touching code.

- [ ] **Step 1:** Confirm the Phoenix server is up and Tidewave is reachable.

Via Tidewave:

```elixir
# Tidewave: project_eval
Application.started_applications() |> Enum.find(fn {app, _, _} -> app == :klass_hero end)
```

Expected: a tuple `{:klass_hero, _description, _version}`. If nil, alert the user that Tidewave/Phoenix is not running before proceeding.

- [ ] **Step 2:** Confirm current branch.

```bash
git branch --show-current
```

Expected: `feat/373-per-session-view`.

- [ ] **Step 3:** Confirm baseline precommit is clean.

```bash
mix precommit
```

Expected: all green. If not, stop and fix before starting work.

---

## Task 1: Add `session_cancelled` Integration Event

**Files:**
- Modify: `lib/klass_hero/participation/domain/events/participation_integration_events.ex`
- Test: `test/klass_hero/participation/domain/events/participation_integration_events_test.exs`

- [ ] **Step 1: Write the failing test**

Append to `test/klass_hero/participation/domain/events/participation_integration_events_test.exs`:

```elixir
describe "session_cancelled/3" do
  test "creates a session_cancelled integration event" do
    event = ParticipationIntegrationEvents.session_cancelled("session-1", %{program_id: "program-1"})

    assert event.event_type == :session_cancelled
    assert event.source_context == :participation
    assert event.entity_type == :session
    assert event.entity_id == "session-1"
    assert event.payload.session_id == "session-1"
    assert event.payload.program_id == "program-1"
  end

  test "raises when session_id is nil" do
    assert_raise ArgumentError, fn ->
      ParticipationIntegrationEvents.session_cancelled(nil, %{program_id: "p"})
    end
  end

  test "raises when program_id is missing" do
    assert_raise ArgumentError, fn ->
      ParticipationIntegrationEvents.session_cancelled("session-1", %{})
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
mix test test/klass_hero/participation/domain/events/participation_integration_events_test.exs --only describe:"session_cancelled/3"
```

Expected: FAIL with `UndefinedFunctionError` or similar (function does not exist). If you get a different failure, stop and investigate.

- [ ] **Step 3: Add the factory function**

In `lib/klass_hero/participation/domain/events/participation_integration_events.ex`, add above the last `end`:

```elixir
# ---------------------------------------------------------------------------
# session_cancelled (entity type: :session)
# ---------------------------------------------------------------------------

@typedoc "Payload for `:session_cancelled` events."
@type session_cancelled_payload :: %{
        required(:session_id) => String.t(),
        required(:program_id) => String.t(),
        optional(atom()) => term()
      }

@doc """
Creates a `session_cancelled` integration event.

Published when a session is cancelled (e.g. provider cancels a scheduled session).
"""
def session_cancelled(session_id, payload \\ %{}, opts \\ [])

def session_cancelled(session_id, %{program_id: _} = payload, opts)
    when is_binary(session_id) and byte_size(session_id) > 0 do
  base_payload = %{session_id: session_id}

  IntegrationEvent.new(
    :session_cancelled,
    @source_context,
    :session,
    session_id,
    Map.merge(payload, base_payload),
    opts
  )
end

def session_cancelled(session_id, payload, _opts) when is_binary(session_id) and byte_size(session_id) > 0 do
  missing = [:program_id] -- Map.keys(payload)

  raise ArgumentError,
        "session_cancelled missing required payload keys: #{inspect(missing)}"
end

def session_cancelled(session_id, _payload, _opts) do
  raise ArgumentError,
        "session_cancelled/3 requires a non-empty session_id string, got: #{inspect(session_id)}"
end
```

Also add `:session_cancelled` to the moduledoc event list near the top.

- [ ] **Step 4: Run the test to verify it passes**

```bash
mix test test/klass_hero/participation/domain/events/participation_integration_events_test.exs --only describe:"session_cancelled/3"
```

Expected: 3 passes.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/participation/domain/events/participation_integration_events.ex \
        test/klass_hero/participation/domain/events/participation_integration_events_test.exs
git commit -m "feat: add session_cancelled integration event"
```

---

## Task 2: Promote `session_cancelled` Domain Event

**Files:**
- Modify: `lib/klass_hero/participation/adapters/driving/events/event_handlers/promote_integration_events.ex`
- Test: `test/klass_hero/participation/adapters/driving/events/event_handlers/promote_integration_events_test.exs`

- [ ] **Step 1:** Find the emission path. Use Tidewave:

```elixir
# Tidewave: project_eval
KlassHero.Participation.Adapters.Driving.Events.EventHandlers.PromoteIntegrationEvents
|> Code.fetch_docs()
```

Verify the module handles each session lifecycle event via a `handle/1` clause.

- [ ] **Step 2: Write the failing test**

Append a describe block to `promote_integration_events_test.exs` mirroring the existing `session_completed` test. Structure:

```elixir
describe "handle/1 for :session_cancelled" do
  test "promotes to integration event and publishes" do
    Phoenix.PubSub.subscribe(KlassHero.PubSub, "integration:participation:session_cancelled")

    event = %DomainEvent{
      event_type: :session_cancelled,
      aggregate_id: "session-42",
      payload: %{program_id: "program-1"}
    }

    assert :ok = PromoteIntegrationEvents.handle(event)

    assert_receive {:integration_event, %IntegrationEvent{event_type: :session_cancelled} = ie}, 200
    assert ie.entity_id == "session-42"
    assert ie.payload.program_id == "program-1"
  end
end
```

(Match the existing file's imports/aliases — copy from a neighboring describe block.)

- [ ] **Step 3: Run the test to verify it fails**

```bash
mix test test/klass_hero/participation/adapters/driving/events/event_handlers/promote_integration_events_test.exs -t describe:"handle/1 for :session_cancelled"
```

Expected: FAIL because no clause matches `:session_cancelled`.

- [ ] **Step 4: Add the handler clause**

In `promote_integration_events.ex`, add after the `session_completed` clause:

```elixir
def handle(%DomainEvent{event_type: :session_cancelled} = event) do
  # Trigger: session_cancelled domain event dispatched when a session is cancelled
  # Why: downstream projections (e.g. ProviderSessionDetails) must mark it cancelled
  # Outcome: best-effort publish; swallow failures since cancellation is already persisted
  ParticipationIntegrationEvents.session_cancelled(event.aggregate_id, event.payload)
  |> IntegrationEventPublishing.publish_best_effort("session_cancelled",
    session_id: event.aggregate_id
  )
end
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
mix test test/klass_hero/participation/adapters/driving/events/event_handlers/promote_integration_events_test.exs
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/participation/adapters/driving/events/event_handlers/promote_integration_events.ex \
        test/klass_hero/participation/adapters/driving/events/event_handlers/promote_integration_events_test.exs
git commit -m "feat: promote session_cancelled domain event to integration event"
```

> **Note on domain emission:** Finding the cancellation use case (if one exists) and wiring the domain event emission is out of this ticket's scope — the projection only needs to react to the event when it *does* arrive. If the cancellation flow does not yet exist in the domain, file a follow-up issue and continue.

---

## Task 3: Migration for `provider_session_details`

**Files:**
- Create: `priv/repo/migrations/<timestamp>_create_provider_session_details.exs`

- [ ] **Step 1: Generate the migration scaffold**

```bash
mix ecto.gen.migration create_provider_session_details
```

Expected: new file under `priv/repo/migrations/` with timestamp prefix.

- [ ] **Step 2: Write the migration**

Replace the generated body with:

```elixir
defmodule KlassHero.Repo.Migrations.CreateProviderSessionDetails do
  use Ecto.Migration

  def change do
    create table(:provider_session_details, primary_key: false) do
      add :session_id,                  :binary_id, primary_key: true
      add :program_id,                  :binary_id, null: false
      add :program_title,               :string,    null: false
      add :provider_id,                 :binary_id, null: false

      add :session_date,                :date,      null: false
      add :start_time,                  :time,      null: false
      add :end_time,                    :time,      null: false
      add :status,                      :string,    null: false

      add :current_assigned_staff_id,   :binary_id
      add :current_assigned_staff_name, :string
      add :cover_staff_id,              :binary_id
      add :cover_staff_name,            :string

      add :checked_in_count,            :integer,   null: false, default: 0
      add :total_count,                 :integer,   null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:provider_session_details, [:provider_id, :program_id, :session_date])
    create index(:provider_session_details, [:provider_id, :session_date])
  end
end
```

- [ ] **Step 3: Run the migration**

```bash
mix ecto.migrate
```

- [ ] **Step 4: Verify the table via Tidewave**

```elixir
# Tidewave: execute_sql_query
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'provider_session_details'
ORDER BY ordinal_position;
```

Expected: 16 columns in the order above; `null` only on the staff/cover columns.

- [ ] **Step 5: Commit**

```bash
git add priv/repo/migrations/*_create_provider_session_details.exs
git commit -m "feat: add provider_session_details read table"
```

---

## Task 4: Ecto Schema, DTO, Mapper

**Files:**
- Create: `lib/klass_hero/provider/domain/read_models/session_detail.ex`
- Create: `lib/klass_hero/provider/adapters/driven/persistence/schemas/provider_session_detail_schema.ex`
- Create: `lib/klass_hero/provider/adapters/driven/persistence/mappers/provider_session_detail_mapper.ex`
- Test: `test/klass_hero/provider/adapters/driven/persistence/mappers/provider_session_detail_mapper_test.exs`

- [ ] **Step 1: Write the DTO**

`lib/klass_hero/provider/domain/read_models/session_detail.ex`:

```elixir
defmodule KlassHero.Provider.Domain.ReadModels.SessionDetail do
  @moduledoc "Display-optimized session detail for the provider dashboard."

  @enforce_keys [:session_id, :program_id, :provider_id, :session_date, :start_time, :end_time, :status]
  defstruct [
    :session_id,
    :program_id,
    :program_title,
    :provider_id,
    :session_date,
    :start_time,
    :end_time,
    :status,
    :current_assigned_staff_id,
    :current_assigned_staff_name,
    :cover_staff_id,
    :cover_staff_name,
    checked_in_count: 0,
    total_count: 0
  ]

  @type status :: :scheduled | :in_progress | :completed | :cancelled

  @type t :: %__MODULE__{
          session_id: binary(),
          program_id: binary(),
          program_title: String.t() | nil,
          provider_id: binary(),
          session_date: Date.t(),
          start_time: Time.t(),
          end_time: Time.t(),
          status: status(),
          current_assigned_staff_id: binary() | nil,
          current_assigned_staff_name: String.t() | nil,
          cover_staff_id: binary() | nil,
          cover_staff_name: String.t() | nil,
          checked_in_count: non_neg_integer(),
          total_count: non_neg_integer()
        }
end
```

- [ ] **Step 2: Write the Ecto schema**

`lib/klass_hero/provider/adapters/driven/persistence/schemas/provider_session_detail_schema.ex`:

```elixir
defmodule KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema do
  @moduledoc """
  Read table for the Provider dashboard's per-session view (issue #373).

  Populated by the `ProviderSessionDetails` projection from Participation + Provider
  integration events. Do not write directly — use the projection.
  """

  use Ecto.Schema

  @primary_key {:session_id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "provider_session_details" do
    field :program_id, :binary_id
    field :program_title, :string
    field :provider_id, :binary_id

    field :session_date, :date
    field :start_time, :time
    field :end_time, :time
    field :status, Ecto.Enum, values: [:scheduled, :in_progress, :completed, :cancelled]

    field :current_assigned_staff_id, :binary_id
    field :current_assigned_staff_name, :string
    field :cover_staff_id, :binary_id
    field :cover_staff_name, :string

    field :checked_in_count, :integer, default: 0
    field :total_count, :integer, default: 0

    timestamps(type: :utc_datetime)
  end
end
```

- [ ] **Step 3: Write the failing mapper test**

`test/klass_hero/provider/adapters/driven/persistence/mappers/provider_session_detail_mapper_test.exs`:

```elixir
defmodule KlassHero.Provider.Adapters.Driven.Persistence.Mappers.ProviderSessionDetailMapperTest do
  use ExUnit.Case, async: true

  alias KlassHero.Provider.Adapters.Driven.Persistence.Mappers.ProviderSessionDetailMapper
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema
  alias KlassHero.Provider.Domain.ReadModels.SessionDetail

  test "to_read_model/1 maps schema struct to DTO with all fields" do
    schema = %ProviderSessionDetailSchema{
      session_id: "s-1",
      program_id: "p-1",
      program_title: "Judo",
      provider_id: "pr-1",
      session_date: ~D[2026-05-01],
      start_time: ~T[15:00:00],
      end_time: ~T[16:00:00],
      status: :scheduled,
      current_assigned_staff_id: "staff-1",
      current_assigned_staff_name: "Alice",
      cover_staff_id: nil,
      cover_staff_name: nil,
      checked_in_count: 3,
      total_count: 5
    }

    assert %SessionDetail{
             session_id: "s-1",
             program_title: "Judo",
             status: :scheduled,
             current_assigned_staff_name: "Alice",
             checked_in_count: 3,
             total_count: 5
           } = ProviderSessionDetailMapper.to_read_model(schema)
  end
end
```

- [ ] **Step 4: Run the test to verify it fails**

```bash
mix test test/klass_hero/provider/adapters/driven/persistence/mappers/provider_session_detail_mapper_test.exs
```

Expected: FAIL with undefined module / function.

- [ ] **Step 5: Write the mapper**

`lib/klass_hero/provider/adapters/driven/persistence/mappers/provider_session_detail_mapper.ex`:

```elixir
defmodule KlassHero.Provider.Adapters.Driven.Persistence.Mappers.ProviderSessionDetailMapper do
  @moduledoc "Maps between ProviderSessionDetailSchema and the SessionDetail read model."

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema
  alias KlassHero.Provider.Domain.ReadModels.SessionDetail

  @spec to_read_model(ProviderSessionDetailSchema.t()) :: SessionDetail.t()
  def to_read_model(%ProviderSessionDetailSchema{} = s) do
    %SessionDetail{
      session_id: s.session_id,
      program_id: s.program_id,
      program_title: s.program_title,
      provider_id: s.provider_id,
      session_date: s.session_date,
      start_time: s.start_time,
      end_time: s.end_time,
      status: s.status,
      current_assigned_staff_id: s.current_assigned_staff_id,
      current_assigned_staff_name: s.current_assigned_staff_name,
      cover_staff_id: s.cover_staff_id,
      cover_staff_name: s.cover_staff_name,
      checked_in_count: s.checked_in_count,
      total_count: s.total_count
    }
  end
end
```

- [ ] **Step 6: Run the test to verify it passes**

```bash
mix test test/klass_hero/provider/adapters/driven/persistence/mappers/provider_session_detail_mapper_test.exs
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero/provider/domain/read_models/session_detail.ex \
        lib/klass_hero/provider/adapters/driven/persistence/schemas/provider_session_detail_schema.ex \
        lib/klass_hero/provider/adapters/driven/persistence/mappers/provider_session_detail_mapper.ex \
        test/klass_hero/provider/adapters/driven/persistence/mappers/provider_session_detail_mapper_test.exs
git commit -m "feat: add SessionDetail DTO, schema, and mapper"
```

---

## Task 5: Port Behaviour

**Files:**
- Create: `lib/klass_hero/provider/domain/ports/for_querying_session_details.ex`

- [ ] **Step 1: Write the port**

```elixir
defmodule KlassHero.Provider.Domain.Ports.ForQueryingSessionDetails do
  @moduledoc """
  Read port for per-session detail rows.

  Implementations query the `provider_session_details` projection table
  (populated by `ProviderSessionDetails` GenServer).
  """

  alias KlassHero.Provider.Domain.ReadModels.SessionDetail

  @callback list_by_program(provider_id :: binary(), program_id :: binary()) :: [SessionDetail.t()]
end
```

- [ ] **Step 2: Verify it compiles**

Via Tidewave:

```elixir
# Tidewave: project_eval
Code.ensure_loaded?(KlassHero.Provider.Domain.Ports.ForQueryingSessionDetails)
```

Expected: `true`.

- [ ] **Step 3: Commit**

```bash
git add lib/klass_hero/provider/domain/ports/for_querying_session_details.ex
git commit -m "feat: add ForQueryingSessionDetails port"
```

---

## Task 6: Repository (implements the port)

**Files:**
- Create: `lib/klass_hero/provider/adapters/driven/persistence/repositories/session_details_repository.ex`
- Test: `test/klass_hero/provider/adapters/driven/persistence/repositories/session_details_repository_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule KlassHero.Provider.Adapters.Driven.Persistence.Repositories.SessionDetailsRepositoryTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Provider.Adapters.Driven.Persistence.Repositories.SessionDetailsRepository
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema
  alias KlassHero.Provider.Domain.ReadModels.SessionDetail
  alias KlassHero.Repo

  defp insert_row(attrs) do
    %ProviderSessionDetailSchema{}
    |> Ecto.Changeset.change(attrs)
    |> Repo.insert!()
  end

  describe "list_by_program/2" do
    test "returns rows ordered by session_date then start_time" do
      provider_id = Ecto.UUID.generate()
      program_id = Ecto.UUID.generate()

      insert_row(%{
        session_id: Ecto.UUID.generate(),
        program_id: program_id,
        program_title: "Judo",
        provider_id: provider_id,
        session_date: ~D[2026-05-02],
        start_time: ~T[09:00:00],
        end_time: ~T[10:00:00],
        status: :scheduled
      })

      insert_row(%{
        session_id: Ecto.UUID.generate(),
        program_id: program_id,
        program_title: "Judo",
        provider_id: provider_id,
        session_date: ~D[2026-05-01],
        start_time: ~T[15:00:00],
        end_time: ~T[16:00:00],
        status: :scheduled
      })

      [first, second] = SessionDetailsRepository.list_by_program(provider_id, program_id)

      assert %SessionDetail{session_date: ~D[2026-05-01]} = first
      assert %SessionDetail{session_date: ~D[2026-05-02]} = second
    end

    test "returns [] for unknown program" do
      assert [] == SessionDetailsRepository.list_by_program(Ecto.UUID.generate(), Ecto.UUID.generate())
    end

    test "does not leak across providers" do
      program_id = Ecto.UUID.generate()
      mine = Ecto.UUID.generate()
      theirs = Ecto.UUID.generate()

      insert_row(%{
        session_id: Ecto.UUID.generate(), program_id: program_id, program_title: "J",
        provider_id: theirs, session_date: ~D[2026-05-01], start_time: ~T[09:00:00],
        end_time: ~T[10:00:00], status: :scheduled
      })

      assert [] == SessionDetailsRepository.list_by_program(mine, program_id)
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
mix test test/klass_hero/provider/adapters/driven/persistence/repositories/session_details_repository_test.exs
```

Expected: FAIL — module not defined.

- [ ] **Step 3: Write the repository**

```elixir
defmodule KlassHero.Provider.Adapters.Driven.Persistence.Repositories.SessionDetailsRepository do
  @moduledoc "Read-only repository for the provider_session_details projection."

  @behaviour KlassHero.Provider.Domain.Ports.ForQueryingSessionDetails

  import Ecto.Query

  alias KlassHero.Provider.Adapters.Driven.Persistence.Mappers.ProviderSessionDetailMapper
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema
  alias KlassHero.Repo

  @impl true
  def list_by_program(provider_id, program_id) when is_binary(provider_id) and is_binary(program_id) do
    from(d in ProviderSessionDetailSchema,
      where: d.provider_id == ^provider_id and d.program_id == ^program_id,
      order_by: [asc: d.session_date, asc: d.start_time]
    )
    |> Repo.all()
    |> Enum.map(&ProviderSessionDetailMapper.to_read_model/1)
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
mix test test/klass_hero/provider/adapters/driven/persistence/repositories/session_details_repository_test.exs
```

Expected: 3 passes.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/provider/adapters/driven/persistence/repositories/session_details_repository.ex \
        test/klass_hero/provider/adapters/driven/persistence/repositories/session_details_repository_test.exs
git commit -m "feat: add SessionDetailsRepository (implements port)"
```

---

## Task 7: Projection GenServer Skeleton

**Files:**
- Create: `lib/klass_hero/provider/adapters/driven/projections/provider_session_details.ex`
- Test: `test/klass_hero/provider/adapters/driven/projections/provider_session_details_test.exs`

- [ ] **Step 1: Write a minimal skeleton test**

```elixir
defmodule KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionDetailsTest do
  use KlassHero.DataCase, async: false

  alias KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionDetails

  setup do
    start_supervised!({ProviderSessionDetails, name: :test_provider_session_details})
    :ok
  end

  test "starts and responds to a ping call" do
    assert Process.whereis(:test_provider_session_details) |> is_pid()
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
mix test test/klass_hero/provider/adapters/driven/projections/provider_session_details_test.exs
```

Expected: FAIL (module undefined).

- [ ] **Step 3: Write the skeleton**

```elixir
defmodule KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionDetails do
  @moduledoc """
  Event-driven projection maintaining `provider_session_details`.

  Subscribes to Participation session/attendance events and Provider staff events.
  Self-heals on every boot by replaying the bootstrap query into the read table.
  """

  use GenServer

  require Logger

  @session_created_topic           "integration:participation:session_created"
  @session_started_topic           "integration:participation:session_started"
  @session_completed_topic         "integration:participation:session_completed"
  @session_cancelled_topic         "integration:participation:session_cancelled"
  @roster_seeded_topic             "integration:participation:roster_seeded"
  @child_checked_in_topic          "integration:participation:child_checked_in"
  @child_checked_out_topic         "integration:participation:child_checked_out"
  @child_marked_absent_topic       "integration:participation:child_marked_absent"
  @staff_assigned_topic            "integration:provider:staff_assigned_to_program"
  @staff_unassigned_topic          "integration:provider:staff_unassigned_from_program"

  @topics [
    @session_created_topic, @session_started_topic, @session_completed_topic,
    @session_cancelled_topic, @roster_seeded_topic,
    @child_checked_in_topic, @child_checked_out_topic, @child_marked_absent_topic,
    @staff_assigned_topic, @staff_unassigned_topic
  ]

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Rebuilds the read table from write models. Useful after seeds."
  def rebuild(name \\ __MODULE__), do: GenServer.call(name, :rebuild, :infinity)

  @impl true
  def init(_opts) do
    Enum.each(@topics, &Phoenix.PubSub.subscribe(KlassHero.PubSub, &1))
    {:ok, %{bootstrapped: false}, {:continue, :bootstrap}}
  end

  @impl true
  def handle_continue(:bootstrap, state) do
    # implementation comes in Task 13
    {:noreply, %{state | bootstrapped: true}}
  end

  @impl true
  def handle_call(:rebuild, _from, state) do
    # implementation comes in Task 13
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:retry_bootstrap, state) do
    {:noreply, state, {:continue, :bootstrap}}
  end

  @impl true
  def handle_info({:integration_event, _event}, state) do
    # event clauses come in Tasks 8–12
    {:noreply, state}
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
mix test test/klass_hero/provider/adapters/driven/projections/provider_session_details_test.exs
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/provider/adapters/driven/projections/provider_session_details.ex \
        test/klass_hero/provider/adapters/driven/projections/provider_session_details_test.exs
git commit -m "feat: scaffold ProviderSessionDetails projection GenServer"
```

---

## Task 8: Handler — `session_created`

**Goal:** when a session is created, insert a row with session timestamps + current program assignment staff. Resolve `program_title` and `provider_id` via a read of the `programs` write table.

**Files:**
- Modify: `lib/klass_hero/provider/adapters/driven/projections/provider_session_details.ex`
- Modify: `test/klass_hero/provider/adapters/driven/projections/provider_session_details_test.exs`

- [ ] **Step 1:** Via Tidewave, confirm the Program Catalog schema module path and field names:

```elixir
# Tidewave: get_ecto_schemas
```

Locate `KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema`. Note fields: `id`, `title`, `provider_id`.

- [ ] **Step 2: Write the failing test**

Append to `provider_session_details_test.exs`:

```elixir
describe "session_created" do
  test "inserts a row with defaults, resolving program_title and provider_id" do
    provider_id = Ecto.UUID.generate()
    program_id = Ecto.UUID.generate()
    session_id = Ecto.UUID.generate()

    # Minimal program row so the handler can resolve title/provider_id
    {:ok, _} = KlassHero.Repo.query(
      "INSERT INTO programs (id, title, provider_id, status, inserted_at, updated_at) VALUES ($1, $2, $3, $4, NOW(), NOW())",
      [Ecto.UUID.dump!(program_id), "Judo", Ecto.UUID.dump!(provider_id), "active"]
    )

    event = build_integration_event(:session_created, session_id, %{
      session_id: session_id,
      program_id: program_id,
      session_date: ~D[2026-05-01],
      start_time: ~T[15:00:00],
      end_time: ~T[16:00:00]
    })

    Phoenix.PubSub.broadcast(KlassHero.PubSub,
      "integration:participation:session_created",
      {:integration_event, event}
    )

    eventually(fn ->
      row = KlassHero.Repo.get(
        KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema,
        session_id
      )
      assert row.program_id == program_id
      assert row.program_title == "Judo"
      assert row.provider_id == provider_id
      assert row.status == :scheduled
      assert row.checked_in_count == 0
      assert row.total_count == 0
    end)
  end
end
```

Add `build_integration_event/3` and `eventually/1` helpers at the top of the module (outside `describe`):

```elixir
defp build_integration_event(event_type, entity_id, payload) do
  KlassHero.Shared.Domain.Events.IntegrationEvent.new(
    event_type,
    :participation,
    :session,
    entity_id,
    payload
  )
end

defp eventually(fun, attempts \\ 20, delay \\ 25) do
  try do
    fun.()
  rescue
    ExUnit.AssertionError when attempts > 0 ->
      Process.sleep(delay)
      eventually(fun, attempts - 1, delay)
  end
end
```

> **Note:** the project's existing projection tests may have a helper already; use it if so — inspect `test/klass_hero/messaging/adapters/driven/projections/` for a canonical `eventually/1`.

- [ ] **Step 3: Run the test to verify it fails**

```bash
mix test test/klass_hero/provider/adapters/driven/projections/provider_session_details_test.exs --only describe:"session_created"
```

Expected: FAIL (row not inserted).

- [ ] **Step 4: Implement the handler**

In `provider_session_details.ex`:

```elixir
alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema
alias KlassHero.Repo
alias KlassHero.Shared.Domain.Events.IntegrationEvent
import Ecto.Query

def handle_info({:integration_event, %IntegrationEvent{event_type: :session_created} = event}, state) do
  project_session_created(event.payload)
  {:noreply, state}
end

defp project_session_created(%{
       session_id: session_id,
       program_id: program_id,
       session_date: session_date,
       start_time: start_time,
       end_time: end_time
     }) do
  {program_title, provider_id} = resolve_program(program_id)
  {staff_id, staff_name} = resolve_current_assigned_staff(program_id)

  now = DateTime.utc_now() |> DateTime.truncate(:second)

  attrs = %{
    session_id: session_id,
    program_id: program_id,
    program_title: program_title,
    provider_id: provider_id,
    session_date: session_date,
    start_time: start_time,
    end_time: end_time,
    status: "scheduled",
    current_assigned_staff_id: staff_id,
    current_assigned_staff_name: staff_name,
    checked_in_count: 0,
    total_count: 0,
    inserted_at: now,
    updated_at: now
  }

  Repo.insert_all(
    "provider_session_details",
    [attrs],
    on_conflict: {:replace_all_except, [:session_id, :inserted_at]},
    conflict_target: [:session_id]
  )
end

defp resolve_program(program_id) do
  # Read from the programs write table. This is a cross-context read scoped to
  # event handling; symmetric with the bootstrap query. If boundary-checker
  # flags it, extract a ProgramCatalog read helper.
  case Repo.query(
         "SELECT title, provider_id FROM programs WHERE id = $1",
         [Ecto.UUID.dump!(program_id)]
       ) do
    {:ok, %{rows: [[title, provider_id_bin]]}} ->
      {title, Ecto.UUID.cast!(provider_id_bin)}

    _ ->
      Logger.warning("session_created: program not found", program_id: program_id)
      {nil, nil}
  end
end

defp resolve_current_assigned_staff(program_id) do
  case Repo.query(
         """
         SELECT psa.staff_member_id, sm.display_name
         FROM program_staff_assignments psa
         JOIN staff_members sm ON sm.id = psa.staff_member_id
         WHERE psa.program_id = $1 AND psa.unassigned_at IS NULL
         ORDER BY psa.assigned_at ASC
         LIMIT 1
         """,
         [Ecto.UUID.dump!(program_id)]
       ) do
    {:ok, %{rows: [[staff_id_bin, name]]}} -> {Ecto.UUID.cast!(staff_id_bin), name}
    _ -> {nil, nil}
  end
end
```

> **Verify column names** with Tidewave before wiring — the `staff_members` table's display column may be `display_name` or `first_name` + `last_name`. Use `get_ecto_schemas` or `execute_sql_query SELECT * FROM staff_members LIMIT 1`.

- [ ] **Step 5: Run the test to verify it passes**

```bash
mix test test/klass_hero/provider/adapters/driven/projections/provider_session_details_test.exs --only describe:"session_created"
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -u
git commit -m "feat: project session_created into provider_session_details"
```

---

## Task 9: Handlers — Status Transitions

**Goal:** `session_started` → `:in_progress`, `session_completed` → `:completed`, `session_cancelled` → `:cancelled`.

**Files:**
- Modify: `lib/klass_hero/provider/adapters/driven/projections/provider_session_details.ex`
- Modify: `test/klass_hero/provider/adapters/driven/projections/provider_session_details_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
describe "status transitions" do
  setup :insert_seed_session

  test "session_started sets status=:in_progress", %{session_id: session_id} do
    broadcast(:session_started, session_id, %{session_id: session_id, program_id: "prog"})

    eventually(fn ->
      assert %{status: :in_progress} = reload(session_id)
    end)
  end

  test "session_completed sets status=:completed", %{session_id: session_id} do
    broadcast(:session_completed, session_id, %{
      session_id: session_id, program_id: "prog", provider_id: "prv", program_title: "Judo"
    })

    eventually(fn -> assert %{status: :completed} = reload(session_id) end)
  end

  test "session_cancelled sets status=:cancelled", %{session_id: session_id} do
    broadcast(:session_cancelled, session_id, %{session_id: session_id, program_id: "prog"})

    eventually(fn -> assert %{status: :cancelled} = reload(session_id) end)
  end
end

defp broadcast(event_type, entity_id, payload) do
  event = build_integration_event(event_type, entity_id, payload)
  Phoenix.PubSub.broadcast(KlassHero.PubSub, "integration:participation:#{event_type}", {:integration_event, event})
end

defp reload(session_id) do
  KlassHero.Repo.get(
    KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema,
    session_id
  )
end

defp insert_seed_session(_ctx) do
  session_id = Ecto.UUID.generate()

  KlassHero.Repo.insert_all("provider_session_details", [%{
    session_id: session_id,
    program_id: Ecto.UUID.generate(),
    program_title: "X",
    provider_id: Ecto.UUID.generate(),
    session_date: ~D[2026-05-01],
    start_time: ~T[09:00:00],
    end_time: ~T[10:00:00],
    status: "scheduled",
    checked_in_count: 0, total_count: 0,
    inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
    updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
  }])

  %{session_id: session_id}
end
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
mix test test/klass_hero/provider/adapters/driven/projections/provider_session_details_test.exs --only describe:"status transitions"
```

Expected: 3 FAILs (no status change).

- [ ] **Step 3: Implement**

In `provider_session_details.ex`:

```elixir
def handle_info({:integration_event, %IntegrationEvent{event_type: :session_started} = event}, state) do
  update_status(event.entity_id, :in_progress)
  {:noreply, state}
end

def handle_info({:integration_event, %IntegrationEvent{event_type: :session_completed} = event}, state) do
  update_status(event.entity_id, :completed)
  {:noreply, state}
end

def handle_info({:integration_event, %IntegrationEvent{event_type: :session_cancelled} = event}, state) do
  update_status(event.entity_id, :cancelled)
  {:noreply, state}
end

defp update_status(session_id, status) do
  from(d in ProviderSessionDetailSchema, where: d.session_id == ^session_id)
  |> Repo.update_all(set: [status: status, updated_at: DateTime.utc_now() |> DateTime.truncate(:second)])
end
```

Delete the fallback `handle_info({:integration_event, _event}, state)` you scaffolded in Task 7 once all event types have explicit clauses (final fallback comes in Task 12).

- [ ] **Step 4: Run the tests to verify they pass**

```bash
mix test test/klass_hero/provider/adapters/driven/projections/provider_session_details_test.exs --only describe:"status transitions"
```

Expected: 3 PASS.

- [ ] **Step 5: Commit**

```bash
git add -u
git commit -m "feat: project session status transitions"
```

---

## Task 10: Handler — `roster_seeded`

- [ ] **Step 1: Write the failing test**

```elixir
describe "roster_seeded" do
  setup :insert_seed_session

  test "sets total_count from seeded_count", %{session_id: session_id} do
    broadcast(:roster_seeded, session_id, %{session_id: session_id, program_id: "p", seeded_count: 7})

    eventually(fn -> assert %{total_count: 7} = reload(session_id) end)
  end
end
```

- [ ] **Step 2: Run to verify it fails**

```bash
mix test test/klass_hero/provider/adapters/driven/projections/provider_session_details_test.exs --only describe:"roster_seeded"
```

Expected: FAIL.

- [ ] **Step 3: Implement**

```elixir
def handle_info({:integration_event, %IntegrationEvent{event_type: :roster_seeded, payload: %{seeded_count: seeded_count}} = event}, state) do
  from(d in ProviderSessionDetailSchema, where: d.session_id == ^event.entity_id)
  |> Repo.update_all(set: [total_count: seeded_count, updated_at: DateTime.utc_now() |> DateTime.truncate(:second)])
  {:noreply, state}
end
```

- [ ] **Step 4: Run to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -u
git commit -m "feat: project roster_seeded total_count"
```

---

## Task 11: Handler — Attendance Counters

**Goal:** `child_checked_in` increments; `child_checked_out` and `child_marked_absent` are explicit no-ops (log at debug).

- [ ] **Step 1: Write the failing tests**

```elixir
describe "attendance counters" do
  setup :insert_seed_session

  test "child_checked_in increments checked_in_count", %{session_id: session_id} do
    broadcast(:child_checked_in, "rec-1", %{record_id: "rec-1", session_id: session_id, child_id: "c-1"})

    eventually(fn -> assert %{checked_in_count: 1} = reload(session_id) end)
  end

  test "two check-ins increment to 2", %{session_id: session_id} do
    broadcast(:child_checked_in, "rec-1", %{record_id: "rec-1", session_id: session_id, child_id: "c-1"})
    broadcast(:child_checked_in, "rec-2", %{record_id: "rec-2", session_id: session_id, child_id: "c-2"})

    eventually(fn -> assert %{checked_in_count: 2} = reload(session_id) end)
  end

  test "child_checked_out does not decrement", %{session_id: session_id} do
    broadcast(:child_checked_in, "rec-1", %{record_id: "rec-1", session_id: session_id, child_id: "c-1"})
    eventually(fn -> assert %{checked_in_count: 1} = reload(session_id) end)

    broadcast(:child_checked_out, "rec-1", %{record_id: "rec-1", session_id: session_id, child_id: "c-1"})

    # Small wait then assert unchanged
    Process.sleep(50)
    assert %{checked_in_count: 1} = reload(session_id)
  end

  test "child_marked_absent does not change count", %{session_id: session_id} do
    broadcast(:child_marked_absent, "rec-1", %{record_id: "rec-1", session_id: session_id, child_id: "c-1"})

    Process.sleep(50)
    assert %{checked_in_count: 0} = reload(session_id)
  end
end
```

- [ ] **Step 2: Run to verify they fail**

Expected: 1st/2nd FAIL (0 instead of 1/2). 3rd/4th may pass by accident if there's still a catch-all clause — remove any catch-all before running.

- [ ] **Step 3: Implement**

```elixir
def handle_info({:integration_event, %IntegrationEvent{event_type: :child_checked_in, payload: %{session_id: session_id}}}, state) do
  from(d in ProviderSessionDetailSchema, where: d.session_id == ^session_id)
  |> Repo.update_all(inc: [checked_in_count: 1],
                      set: [updated_at: DateTime.utc_now() |> DateTime.truncate(:second)])
  {:noreply, state}
end

def handle_info({:integration_event, %IntegrationEvent{event_type: :child_checked_out}}, state) do
  # Intentional no-op: once a child is counted on check-in, they stay counted.
  {:noreply, state}
end

def handle_info({:integration_event, %IntegrationEvent{event_type: :child_marked_absent}}, state) do
  # Intentional no-op: absence does not affect checked_in_count.
  {:noreply, state}
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Expected: 4 PASS.

- [ ] **Step 5: Commit**

```bash
git add -u
git commit -m "feat: project attendance counters"
```

---

## Task 12: Handlers — Staff Assignment / Unassignment

**Goal:** Bulk-update `current_assigned_staff_*` on all `:scheduled` rows for a program.

- [ ] **Step 1:** Via Tidewave, confirm `staff_members` has the display column we use:

```elixir
# Tidewave: execute_sql_query
SELECT column_name FROM information_schema.columns
WHERE table_name = 'staff_members' ORDER BY ordinal_position;
```

Note the column name (e.g. `display_name` or `full_name`). Adjust the SQL below accordingly.

- [ ] **Step 2: Write the failing tests**

```elixir
describe "staff assignment" do
  test "staff_assigned_to_program updates scheduled sessions for the program" do
    program_id = Ecto.UUID.generate()
    scheduled_id = Ecto.UUID.generate()
    completed_id = Ecto.UUID.generate()
    staff_id = Ecto.UUID.generate()

    KlassHero.Repo.query!(
      "INSERT INTO staff_members (id, provider_id, display_name, inserted_at, updated_at) VALUES ($1, $2, $3, NOW(), NOW())",
      [Ecto.UUID.dump!(staff_id), Ecto.UUID.dump!(Ecto.UUID.generate()), "Alice"]
    )

    insert_detail(session_id: scheduled_id, program_id: program_id, status: "scheduled")
    insert_detail(session_id: completed_id, program_id: program_id, status: "completed")

    event = build_integration_event(:staff_assigned_to_program, staff_id, %{
      staff_member_id: staff_id,
      program_id: program_id,
      provider_id: Ecto.UUID.generate()
    })

    Phoenix.PubSub.broadcast(KlassHero.PubSub,
      "integration:provider:staff_assigned_to_program",
      {:integration_event, event}
    )

    eventually(fn ->
      assert %{current_assigned_staff_id: ^staff_id, current_assigned_staff_name: "Alice"} =
               reload(scheduled_id)
      assert %{current_assigned_staff_id: nil} = reload(completed_id)
    end)
  end

  test "staff_unassigned_from_program clears scheduled rows for the program" do
    # similar setup — insert a scheduled row with staff, then broadcast unassign,
    # assert staff_id is nil after
  end
end

defp insert_detail(attrs) do
  base = %{
    session_id: Ecto.UUID.generate(),
    program_id: Ecto.UUID.generate(),
    program_title: "P",
    provider_id: Ecto.UUID.generate(),
    session_date: ~D[2026-05-01],
    start_time: ~T[09:00:00],
    end_time: ~T[10:00:00],
    status: "scheduled",
    checked_in_count: 0, total_count: 0,
    inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
    updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
  }
  KlassHero.Repo.insert_all("provider_session_details", [Map.merge(base, Map.new(attrs))])
end
```

- [ ] **Step 3: Run to verify they fail**

Expected: 2 FAIL.

- [ ] **Step 4: Implement**

```elixir
def handle_info({:integration_event, %IntegrationEvent{event_type: :staff_assigned_to_program, payload: payload}}, state) do
  %{staff_member_id: staff_id, program_id: program_id} = payload
  staff_name = lookup_staff_name(staff_id)

  from(d in ProviderSessionDetailSchema,
    where: d.program_id == ^program_id and d.status == :scheduled
  )
  |> Repo.update_all(
    set: [
      current_assigned_staff_id: staff_id,
      current_assigned_staff_name: staff_name,
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    ]
  )

  {:noreply, state}
end

def handle_info({:integration_event, %IntegrationEvent{event_type: :staff_unassigned_from_program, payload: %{program_id: program_id}}}, state) do
  from(d in ProviderSessionDetailSchema,
    where: d.program_id == ^program_id and d.status == :scheduled
  )
  |> Repo.update_all(
    set: [
      current_assigned_staff_id: nil,
      current_assigned_staff_name: nil,
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    ]
  )

  {:noreply, state}
end

defp lookup_staff_name(staff_id) do
  case Repo.query(
         "SELECT display_name FROM staff_members WHERE id = $1",
         [Ecto.UUID.dump!(staff_id)]
       ) do
    {:ok, %{rows: [[name]]}} -> name
    _ -> nil
  end
end
```

Then add a final catch-all for unknown events:

```elixir
def handle_info({:integration_event, _event}, state), do: {:noreply, state}
```

- [ ] **Step 5: Run the tests to verify they pass**

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -u
git commit -m "feat: project staff assignment changes for scheduled sessions"
```

---

## Task 13: Bootstrap + `rebuild/0`

**Files:**
- Modify: `lib/klass_hero/provider/adapters/driven/projections/provider_session_details.ex`
- Create: `test/klass_hero/provider/adapters/driven/projections/provider_session_details_bootstrap_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionDetailsBootstrapTest do
  use KlassHero.DataCase, async: false

  alias KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionDetails
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema
  alias KlassHero.Repo

  @tag :bootstrap
  test "bootstrap projects every existing session from write tables" do
    # Seed the write tables (bypassing events)
    provider_id = Ecto.UUID.generate()
    program_id = Ecto.UUID.generate()
    session_id = Ecto.UUID.generate()

    Repo.query!(
      "INSERT INTO programs (id, title, provider_id, status, inserted_at, updated_at) VALUES ($1, $2, $3, 'active', NOW(), NOW())",
      [Ecto.UUID.dump!(program_id), "Judo", Ecto.UUID.dump!(provider_id)]
    )

    Repo.query!(
      """
      INSERT INTO program_sessions (id, program_id, session_date, start_time, end_time, status, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, 'scheduled', NOW(), NOW())
      """,
      [Ecto.UUID.dump!(session_id), Ecto.UUID.dump!(program_id), ~D[2026-05-01], ~T[15:00:00], ~T[16:00:00]]
    )

    start_supervised!({ProviderSessionDetails, name: :bootstrap_test})
    :ok = ProviderSessionDetails.rebuild(:bootstrap_test)

    row = Repo.get(ProviderSessionDetailSchema, session_id)
    assert row.program_title == "Judo"
    assert row.provider_id == provider_id
    assert row.status == :scheduled
  end
end
```

- [ ] **Step 2: Run to verify it fails**

```bash
mix test test/klass_hero/provider/adapters/driven/projections/provider_session_details_bootstrap_test.exs
```

Expected: FAIL (no row).

- [ ] **Step 3: Implement the bootstrap query**

Replace the placeholder `handle_continue(:bootstrap, state)` and `handle_call(:rebuild, ...)` in `provider_session_details.ex`:

```elixir
@impl true
def handle_continue(:bootstrap, state) do
  case do_bootstrap() do
    :ok ->
      {:noreply, %{state | bootstrapped: true}}

    {:error, reason} ->
      Logger.warning("ProviderSessionDetails bootstrap failed; retrying", reason: inspect(reason))
      Process.send_after(self(), :retry_bootstrap, 1_000)
      {:noreply, state}
  end
end

@impl true
def handle_call(:rebuild, _from, state) do
  :ok = do_bootstrap()
  {:reply, :ok, %{state | bootstrapped: true}}
end

defp do_bootstrap do
  sql = """
  SELECT
    ps.id::text                            AS session_id,
    ps.program_id::text                    AS program_id,
    p.title                                AS program_title,
    p.provider_id::text                    AS provider_id,
    ps.session_date,
    ps.start_time,
    ps.end_time,
    ps.status::text                        AS status,
    psa.staff_member_id::text              AS current_assigned_staff_id,
    sm.display_name                        AS current_assigned_staff_name,
    COALESCE(counts.checked_in, 0)         AS checked_in_count,
    COALESCE(counts.total, 0)              AS total_count
  FROM program_sessions ps
  JOIN programs p ON p.id = ps.program_id
  LEFT JOIN program_staff_assignments psa
         ON psa.program_id = ps.program_id
        AND psa.unassigned_at IS NULL
  LEFT JOIN staff_members sm
         ON sm.id = psa.staff_member_id
  LEFT JOIN (
    SELECT session_id,
           COUNT(*) FILTER (WHERE status IN ('checked_in','checked_out')) AS checked_in,
           COUNT(*) AS total
    FROM participation_records
    GROUP BY session_id
  ) counts ON counts.session_id = ps.id
  """

  case Repo.query(sql) do
    {:ok, %{rows: rows}} ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      attrs_list =
        Enum.map(rows, fn [sid, pid, title, prov, date, stime, etime, status, staff_id, staff_name, cin, total] ->
          %{
            session_id: sid,
            program_id: pid,
            program_title: title,
            provider_id: prov,
            session_date: date,
            start_time: stime,
            end_time: etime,
            status: status,
            current_assigned_staff_id: staff_id,
            current_assigned_staff_name: staff_name,
            checked_in_count: cin,
            total_count: total,
            inserted_at: now,
            updated_at: now
          }
        end)

      _ = Repo.insert_all(
        "provider_session_details",
        attrs_list,
        on_conflict: {:replace_all_except, [:session_id, :inserted_at]},
        conflict_target: [:session_id]
      )

      :ok

    {:error, reason} ->
      {:error, reason}
  end
end
```

Adjust staff display column name (`display_name` vs. `full_name`) based on Task 12's Tidewave check.

- [ ] **Step 4: Run the test to verify it passes**

```bash
mix test test/klass_hero/provider/adapters/driven/projections/provider_session_details_bootstrap_test.exs
```

Expected: PASS.

- [ ] **Step 5: Verify bootstrap output via Tidewave**

```elixir
# Tidewave: execute_sql_query
SELECT COUNT(*) FROM provider_session_details;
SELECT COUNT(*) FROM program_sessions;
```

Counts should match once the projection is running in the dev environment.

- [ ] **Step 6: Commit**

```bash
git add -u
git commit -m "feat: bootstrap ProviderSessionDetails from write tables"
```

---

## Task 14: Supervisor Registration + DI Wiring

**Files:**
- Modify: `lib/klass_hero/projection_supervisor.ex`
- Modify: `config/config.exs`

- [ ] **Step 1:** Verify the supervisor list via Tidewave:

```elixir
# Tidewave: project_eval
Supervisor.which_children(KlassHero.ProjectionSupervisor)
```

Note current children; the new projection will join them.

- [ ] **Step 2:** Add the projection to the supervisor.

In `lib/klass_hero/projection_supervisor.ex`, add alias and child:

```elixir
alias KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionDetails
# ...
children = [
  VerifiedProviders,
  ProgramListings,
  EnrolledChildren,
  ConversationSummaries,
  ProviderSessionStats,
  ProviderSessionDetails
]
```

- [ ] **Step 3:** Wire the port in `config/config.exs` under the existing `:provider` key:

```elixir
config :klass_hero, :provider,
  # ... existing bindings ...,
  for_querying_session_details:
    KlassHero.Provider.Adapters.Driven.Persistence.Repositories.SessionDetailsRepository
```

- [ ] **Step 4:** Verify compile + boot.

```bash
mix compile --warnings-as-errors
iex -S mix phx.server  # Then Ctrl+C twice to exit, or leave running for Tidewave
```

Via Tidewave, confirm the projection is supervised:

```elixir
Supervisor.which_children(KlassHero.ProjectionSupervisor)
|> Enum.map(fn {mod, _, _, _} -> mod end)
```

Expected: list includes `ProviderSessionDetails`.

- [ ] **Step 5:** Commit.

```bash
git add -u
git commit -m "chore: supervise ProviderSessionDetails and wire port binding"
```

---

## Task 15: Use Case — `ListProgramSessions`

**Files:**
- Create: `lib/klass_hero/provider/application/queries/list_program_sessions.ex`
- Test: `test/klass_hero/provider/application/queries/list_program_sessions_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule KlassHero.Provider.Application.Queries.ListProgramSessionsTest do
  use ExUnit.Case, async: true

  import Mox

  alias KlassHero.Provider.Application.Queries.ListProgramSessions

  setup :verify_on_exit!

  test "delegates to the port with (provider_id, program_id)" do
    provider_id = Ecto.UUID.generate()
    program_id = Ecto.UUID.generate()
    expected = []

    KlassHero.Provider.ForQueryingSessionDetailsMock
    |> expect(:list_by_program, fn ^provider_id, ^program_id -> expected end)

    assert ^expected = ListProgramSessions.run(provider_id, program_id)
  end
end
```

- [ ] **Step 2:** Add the mock. In `test/support/mocks.ex` (or equivalent — check the repo's convention):

```elixir
Mox.defmock(KlassHero.Provider.ForQueryingSessionDetailsMock,
  for: KlassHero.Provider.Domain.Ports.ForQueryingSessionDetails)
```

In `config/test.exs`:

```elixir
config :klass_hero, :provider,
  for_querying_session_details: KlassHero.Provider.ForQueryingSessionDetailsMock
```

- [ ] **Step 3: Run to verify it fails**

```bash
mix test test/klass_hero/provider/application/queries/list_program_sessions_test.exs
```

Expected: FAIL.

- [ ] **Step 4: Implement**

```elixir
defmodule KlassHero.Provider.Application.Queries.ListProgramSessions do
  @moduledoc "Lists per-session detail rows for a provider's program."

  alias KlassHero.Provider.Domain.ReadModels.SessionDetail

  @for_querying_session_details Application.compile_env!(
                                  :klass_hero,
                                  [:provider, :for_querying_session_details]
                                )

  @spec run(binary(), binary()) :: [SessionDetail.t()]
  def run(provider_id, program_id),
    do: @for_querying_session_details.list_by_program(provider_id, program_id)
end
```

- [ ] **Step 5: Run the test to verify it passes**

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -u
git commit -m "feat: add ListProgramSessions query use case"
```

---

## Task 16: Extend `participation_status` with `:cancelled`

**Files:**
- Modify: `lib/klass_hero_web/components/participation_components.ex`
- Test: `test/klass_hero_web/components/participation_components_test.exs` (create if missing)

- [ ] **Step 1: Write the failing test**

```elixir
test "participation_status renders :cancelled with red badge and x-circle icon" do
  html =
    render_component(&KlassHeroWeb.ParticipationComponents.participation_status/1,
      status: :cancelled, size: "sm"
    )

  assert html =~ "bg-red-100"
  assert html =~ "hero-x-circle"
  assert html =~ "Cancelled"
end
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — unmatched status.

- [ ] **Step 3: Implement**

Add three new clauses to the private helpers in `participation_components.ex`:

```elixir
defp status_color_classes(:cancelled), do: "bg-red-100 text-red-700 border border-red-300"
defp status_icon(:cancelled), do: "hero-x-circle"
defp status_label(:cancelled), do: gettext("Cancelled")
```

(Replace helper names if the file uses different ones — read the existing code at `participation_components.ex:126` first.)

- [ ] **Step 4: Run the test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Regenerate gettext POT**

```bash
mix gettext.extract --merge
```

Add German translation for `Cancelled` in `priv/gettext/de/LC_MESSAGES/default.po` → `"Abgesagt"`.

- [ ] **Step 6: Commit**

```bash
git add -u
git commit -m "feat: extend participation_status with :cancelled variant"
```

---

## Task 17: `sessions_modal/1` Component

**Files:**
- Modify: `lib/klass_hero_web/components/provider_components.ex`
- Test: `test/klass_hero_web/components/provider_components_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
describe "sessions_modal/1" do
  test "renders the provided sessions in order" do
    modal = %{
      program_id: "prog-1",
      program_title: "Judo",
      sessions: [
        %KlassHero.Provider.Domain.ReadModels.SessionDetail{
          session_id: "s-1", program_id: "prog-1", provider_id: "prv-1",
          session_date: ~D[2026-05-01], start_time: ~T[15:00:00], end_time: ~T[16:00:00],
          status: :scheduled, program_title: "Judo",
          current_assigned_staff_name: "Alice",
          checked_in_count: 0, total_count: 0
        },
        %KlassHero.Provider.Domain.ReadModels.SessionDetail{
          session_id: "s-2", program_id: "prog-1", provider_id: "prv-1",
          session_date: ~D[2026-05-08], start_time: ~T[15:00:00], end_time: ~T[16:00:00],
          status: :cancelled, program_title: "Judo",
          current_assigned_staff_name: nil,
          checked_in_count: 0, total_count: 0
        }
      ]
    }

    html = render_component(&KlassHeroWeb.ProviderComponents.sessions_modal/1, modal: modal)

    assert html =~ "Judo"
    assert html =~ "Alice"
    assert html =~ "Unassigned"
    # Cancelled row hides attendance
    refute html =~ ~r/0\s*\/\s*0.*cancelled/is
  end

  test "shows empty state when sessions is []" do
    modal = %{program_id: "p", program_title: "T", sessions: []}
    html = render_component(&KlassHeroWeb.ProviderComponents.sessions_modal/1, modal: modal)
    assert html =~ "No sessions scheduled yet"
  end
end
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — function not defined.

- [ ] **Step 3: Implement**

In `provider_components.ex`, add below `roster_modal/1`:

```elixir
@doc """
Renders a modal listing every session of a program with date/time, assigned
staff, cover staff (reserved), attendance count, and status.

## Example

    <.sessions_modal :if={@sessions_modal} modal={@sessions_modal} />
"""
attr :modal, :map, required: true

def sessions_modal(assigns) do
  ~H"""
  <div
    id="sessions-modal"
    role="dialog"
    aria-modal="true"
    aria-labelledby="sessions-modal-title"
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
    phx-window-keydown="close_sessions"
    phx-key="escape"
  >
    <div
      class="bg-white rounded-lg shadow-xl max-w-4xl w-full max-h-[80vh] overflow-hidden flex flex-col"
      phx-click-away="close_sessions"
    >
      <div class="flex items-center justify-between px-6 py-4 border-b">
        <h2 id="sessions-modal-title" class={Theme.typography(:section_title)}>
          {gettext("Sessions — %{title}", title: @modal.program_title)}
        </h2>
        <button type="button" phx-click="close_sessions" aria-label={gettext("Close")}>
          <.icon name="hero-x-mark" class="w-5 h-5" />
        </button>
      </div>

      <div class="flex-1 overflow-y-auto">
        <%= if @modal.sessions == [] do %>
          <div class="text-center py-12">
            <.icon name="hero-calendar-days" class="w-12 h-12 text-hero-grey-300 mx-auto" />
            <p class="mt-4 text-hero-grey-500">{gettext("No sessions scheduled yet.")}</p>
          </div>
        <% else %>
          <table class="w-full text-sm">
            <thead class="bg-hero-grey-50 text-left">
              <tr>
                <th class="px-4 py-3">{gettext("Date / time")}</th>
                <th class="px-4 py-3">{gettext("Assigned staff")}</th>
                <th class="px-4 py-3">{gettext("Cover")}</th>
                <th class="px-4 py-3">{gettext("Attendance")}</th>
                <th class="px-4 py-3">{gettext("Status")}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={s <- @modal.sessions} class="border-t">
                <td class="px-4 py-3">
                  {Calendar.strftime(s.session_date, "%a, %d %b")}
                  <span class="text-hero-grey-500">
                    · {Calendar.strftime(s.start_time, "%H:%M")}–{Calendar.strftime(s.end_time, "%H:%M")}
                  </span>
                </td>
                <td class="px-4 py-3">
                  {s.current_assigned_staff_name || gettext("Unassigned")}
                </td>
                <td class="px-4 py-3 text-hero-grey-500">
                  {s.cover_staff_name || "—"}
                </td>
                <td class="px-4 py-3">
                  <span :if={s.status != :cancelled}>
                    {s.checked_in_count} / {s.total_count}
                  </span>
                </td>
                <td class="px-4 py-3">
                  <.participation_status status={s.status} size="sm" />
                </td>
              </tr>
            </tbody>
          </table>
        <% end %>
      </div>
    </div>
  </div>
  """
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Expected: PASS.

- [ ] **Step 5:** Extract new gettext strings.

```bash
mix gettext.extract --merge
```

Translate new keys in `priv/gettext/de/LC_MESSAGES/default.po`.

- [ ] **Step 6: Commit**

```bash
git add -u
git commit -m "feat: add sessions_modal component"
```

---

## Task 18: Sessions Button in `programs_table` Actions

**Files:**
- Modify: `lib/klass_hero_web/components/provider_components.ex`
- Test: `test/klass_hero_web/components/provider_components_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
test "programs_table renders a Sessions button per row" do
  program = %{
    id: "prog-1", title: "Judo", status: :active,
    # whatever else the existing programs_table expects — copy from existing tests
  }

  html = render_component(&KlassHeroWeb.ProviderComponents.programs_table/1, programs: [program])

  assert html =~ "phx-click=\"view_sessions\""
  assert html =~ "phx-value-program-id=\"prog-1\""
  assert html =~ ~s|aria-label="View sessions"|
end
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — button absent.

- [ ] **Step 3: Add the button**

In `provider_components.ex` around line 1366–1385 (the existing Actions cluster), add:

```heex
<button
  type="button"
  phx-click="view_sessions"
  phx-value-program-id={@program.id}
  phx-value-program-title={@program.title}
  class={icon_button_classes()}
  aria-label={gettext("View sessions")}
>
  <.icon name="hero-calendar-days" class="w-5 h-5" />
</button>
```

(Use the existing `icon_button_classes/0` helper if that's the convention; otherwise mirror the classes used on the Preview / Roster buttons.)

- [ ] **Step 4: Run the test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -u
git commit -m "feat: add Sessions button to programs_table Actions"
```

---

## Task 19: DashboardLive Handlers

**Files:**
- Modify: `lib/klass_hero_web/live/provider_live/dashboard_live.ex`
- Modify: `lib/klass_hero_web/live/provider_live/dashboard_live.html.heex` (if template is separate)

- [ ] **Step 1:** Via Tidewave, inspect the LiveView module:

```elixir
# Tidewave: get_source_location
{KlassHeroWeb.ProviderLive.DashboardLive, :mount}
```

Note where to add the handlers and template hook.

- [ ] **Step 2: Write the failing LiveView test**

Append to the existing dashboard test:

```elixir
test "clicking Sessions opens the modal with the program's sessions", %{conn: conn, provider: provider} do
  program = seed_program_with_session!(provider, title: "Judo")

  {:ok, view, _html} = live(conn, ~p"/provider/dashboard?tab=programs")

  view
  |> element(~s|button[phx-click="view_sessions"][phx-value-program-id="#{program.id}"]|)
  |> render_click()

  assert has_element?(view, "#sessions-modal")
  assert has_element?(view, "#sessions-modal td", "Judo") or
         render(view) =~ "Judo"

  # Close via X
  view |> element("#sessions-modal button[phx-click='close_sessions']") |> render_click()
  refute has_element?(view, "#sessions-modal")
end
```

`seed_program_with_session!/2` should insert a program row, a program_session row, and then call `ProviderSessionDetails.rebuild(...)` so the projection sees them. Implement it in the test helpers module.

- [ ] **Step 3: Run to verify it fails**

```bash
mix test test/klass_hero_web/live/provider_live/dashboard_live_test.exs:<line>
```

Expected: FAIL.

- [ ] **Step 4: Implement**

In `dashboard_live.ex`:

```elixir
alias KlassHero.Provider.Application.Queries.ListProgramSessions

@impl true
def mount(_params, _session, socket) do
  # ... existing logic ...
  {:ok, assign(socket, :sessions_modal, nil)}
end

@impl true
def handle_event("view_sessions",
      %{"program-id" => program_id, "program-title" => title}, socket) do
  provider_id = socket.assigns.current_scope.user.provider_id
  sessions = ListProgramSessions.run(provider_id, program_id)

  {:noreply,
   assign(socket, :sessions_modal,
     %{program_id: program_id, program_title: title, sessions: sessions})}
end

def handle_event("close_sessions", _params, socket) do
  {:noreply, assign(socket, :sessions_modal, nil)}
end
```

In the template:

```heex
<.sessions_modal :if={@sessions_modal} modal={@sessions_modal} />
```

(Place near existing modals. Confirm `ProviderComponents` is already imported in the view; if not, add `import KlassHeroWeb.ProviderComponents` in the layout/html.)

- [ ] **Step 5: Run the test to verify it passes**

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -u
git commit -m "feat: wire sessions modal into provider dashboard"
```

---

## Task 20: End-to-End Precommit & Architecture Review

- [ ] **Step 1:** Run `mix precommit`:

```bash
mix precommit
```

Expected: all green. If anything fails, fix and rerun.

- [ ] **Step 2:** Run the architecture review:

Invoke the `review-architecture` skill:

```
/review-architecture
```

Expected findings + resolutions:

- **Boundary-checker may flag `Repo.query("SELECT ... FROM programs")` inside Provider context.** Mitigation: introduce `KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramReadForProjections.get_title_and_provider/1` (or similar), wire it via a new read-only port, and call it from the projection. Same for staff_members (same context — acceptable) and the bootstrap SQL.
- **Architecture-reviewer should see** the new port in `ports/`, the repository in `adapters/driven/`, and wiring in `config/config.exs` — all conforming.

If flags are structural (bad naming, wrong directory), fix before proceeding.

- [ ] **Step 3:** Use Tidewave to sanity-check projection state in dev:

```elixir
# Tidewave: execute_sql_query
SELECT provider_id, COUNT(*) FROM provider_session_details GROUP BY provider_id;
```

Counts should align with expected provider ↔ session relationships.

- [ ] **Step 4:** Use Tidewave to tail logs during a manual smoke test:

```elixir
# Tidewave: get_logs
tail: 200
```

Create a session manually in dev; observe the projection consuming `session_created`.

- [ ] **Step 5:** Commit any review fixes.

```bash
git add -u && git commit -m "refactor: address architecture-review feedback"
```

---

## Task 21: PR

- [ ] **Step 1:** Push the branch.

```bash
git pull --rebase
git push -u origin feat/373-per-session-view
```

- [ ] **Step 2:** Open the PR.

```bash
gh pr create --title "feat: per-session view in provider dashboard (#373)" --body "$(cat <<'EOF'
## Summary
- New `ProviderSessionDetails` projection in the Provider context, subscribed to Participation + Provider integration events.
- Sessions button + modal on provider dashboard showing date/time, assigned staff, cover (reserved), attendance, status.
- Extended `participation_status` with `:cancelled` variant; added `session_cancelled` integration event.

Closes #373.

## Review Focus
- Projection event handlers and idempotency/ordering behavior (see spec).
- Bootstrap cross-context read pattern (acknowledged; fallback to per-context helpers if boundary-checker flags).
- Staff reassignment "scheduled-only" rule.

## Test Plan
- [ ] `mix precommit` green.
- [ ] Projection unit, bootstrap, repository, use-case, component, and LiveView tests all pass.
- [ ] `/review-architecture` clean or with only known-mitigated findings.
- [ ] Manual dev smoke: create a session, cancel a session, check-in a child → modal reflects each change.

## Follow-ups
- Migrate `list_admin_sessions/1` to the same projection (separate ticket).
- Implement cover-provider domain support (#373 sub-issue).
EOF
)"
```

- [ ] **Step 3:** Paste the PR URL back to the user.

---

## Self-Review Checklist

- **Spec coverage:**
  - ✅ Port contract — Task 5
  - ✅ Read model DTO — Task 4
  - ✅ Schema + migration — Tasks 3–4
  - ✅ Projection + all 10 event handlers — Tasks 7–12
  - ✅ Bootstrap + rebuild — Task 13
  - ✅ Supervision + DI — Task 14
  - ✅ Use case — Task 15
  - ✅ UI component extension (participation_status :cancelled) — Task 16
  - ✅ sessions_modal — Task 17
  - ✅ Sessions button — Task 18
  - ✅ LiveView wiring — Task 19
  - ✅ Testing strategy (6 layers) — Tasks 1, 2, 4, 6, 9–13, 16–19
  - ✅ Rollout/Review — Task 20
  - ✅ Open items — Resolved in Pre-flight + Tasks 1, 2, 14

- **Placeholder scan:** No TBDs; every step has code or commands.

- **Type consistency:**
  - `SessionDetail.t()` used consistently.
  - Port callback `list_by_program/2` matches in port, repo, and use case.
  - Projection module name `ProviderSessionDetails` used consistently.
  - Read table name `provider_session_details` used consistently.
  - Topics strings consistent with source-of-truth event factory patterns.

- **Scope check:** Single feature, single plan. Follow-ups are named and deferred.
