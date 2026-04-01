# Staff Messaging Parents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow staff members assigned to a program to participate in message conversations with parents enrolled in that program, alongside the business account.

**Architecture:** Provider context owns program-staff assignments and publishes integration events. Messaging context maintains a projection table (`program_staff_participants`) kept in sync by event handlers, and uses it to auto-add staff as participants in conversations. No cross-context ACL — Messaging stays self-contained for reads.

**Tech Stack:** Elixir 1.20, Phoenix 1.8, LiveView 1.1, PostgreSQL, Ecto, Oban, PubSub

**Spec:** `docs/superpowers/specs/2026-04-01-staff-messaging-parents-design.md`

**Methodology:** TDD (test first, then implement). Use Tidewave MCP (`project_eval`, `get_docs`, `execute_sql_query`) extensively for verification at each step.

---

## File Structure

### Provider Context (New Files)

| File | Responsibility |
|------|----------------|
| `lib/klass_hero/provider/domain/models/program_staff_assignment.ex` | Domain model struct |
| `lib/klass_hero/provider/domain/ports/for_storing_program_staff_assignments.ex` | Driven port (persistence contract) |
| `lib/klass_hero/provider/adapters/driven/persistence/schemas/program_staff_assignment_schema.ex` | Ecto schema |
| `lib/klass_hero/provider/adapters/driven/persistence/mappers/program_staff_assignment_mapper.ex` | Schema <-> Domain mapper |
| `lib/klass_hero/provider/adapters/driven/persistence/repositories/program_staff_assignment_repository.ex` | Repository adapter |
| `lib/klass_hero/provider/application/use_cases/staff_members/assign_staff_to_program.ex` | Assign use case |
| `lib/klass_hero/provider/application/use_cases/staff_members/unassign_staff_from_program.ex` | Unassign use case |
| `priv/repo/migrations/TIMESTAMP_create_program_staff_assignments.exs` | Migration |

### Messaging Context (New Files)

| File | Responsibility |
|------|----------------|
| `lib/klass_hero/messaging/domain/ports/for_resolving_program_staff.ex` | Driven port (projection query contract) |
| `lib/klass_hero/messaging/adapters/driven/persistence/schemas/program_staff_participant_schema.ex` | Projection Ecto schema |
| `lib/klass_hero/messaging/adapters/driven/persistence/repositories/program_staff_participant_repository.ex` | Projection repository |
| `lib/klass_hero/messaging/adapters/driving/events/staff_assignment_handler.ex` | Integration event handler |
| `priv/repo/migrations/TIMESTAMP_create_program_staff_participants.exs` | Migration |

### Modified Files

| File | Change |
|------|--------|
| `lib/klass_hero/provider/domain/events/provider_integration_events.ex` | Add `staff_assigned_to_program` and `staff_unassigned_from_program` events |
| `lib/klass_hero/provider/adapters/driving/events/event_handlers/promote_integration_events.ex` | Handle new domain events |
| `lib/klass_hero/provider.ex` | Expose assign/unassign in facade |
| `config/config.exs` | Register new ports for both contexts |
| `lib/klass_hero/application.ex` | Register new event handler + subscriber, DomainEventBus handlers |
| `lib/klass_hero/messaging/application/use_cases/create_direct_conversation.ex` | Add assigned staff as participants |
| `lib/klass_hero/messaging/application/use_cases/broadcast_to_program.ex` | Add assigned staff as participants |
| `lib/klass_hero/messaging/application/use_cases/send_message.ex` | Allow staff to send in broadcasts |
| `lib/klass_hero/messaging.ex` | Expose new facade functions |
| `lib/klass_hero/messaging/adapters/driven/projections/conversation_summaries.ex` | Handle staff participant additions |
| `lib/klass_hero_web/components/messaging_components.ex` | Provider-branded attribution |
| `lib/klass_hero_web/live/messaging_live_helper.ex` | Pass `provider_user_ids` to components |
| `test/support/factory.ex` | Add `program_staff_assignment_schema` factory |

---

## Task 1: Provider Context — Migration & Schema

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_program_staff_assignments.exs`
- Create: `lib/klass_hero/provider/adapters/driven/persistence/schemas/program_staff_assignment_schema.ex`
- Test: `test/klass_hero/provider/adapters/driven/persistence/schemas/program_staff_assignment_schema_test.exs`

- [ ] **Step 1: Write the migration**

```elixir
defmodule KlassHero.Repo.Migrations.CreateProgramStaffAssignments do
  use Ecto.Migration

  def change do
    create table(:program_staff_assignments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider_id, references(:providers, type: :binary_id, on_delete: :delete_all), null: false
      add :program_id, references(:programs, type: :binary_id, on_delete: :delete_all), null: false
      add :staff_member_id, references(:staff_members, type: :binary_id, on_delete: :delete_all), null: false
      add :assigned_at, :utc_datetime_usec, null: false
      add :unassigned_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:program_staff_assignments, [:provider_id])
    create index(:program_staff_assignments, [:program_id])
    create index(:program_staff_assignments, [:staff_member_id])

    create unique_index(:program_staff_assignments, [:program_id, :staff_member_id],
      where: "unassigned_at IS NULL",
      name: :program_staff_assignments_active_unique
    )
  end
end
```

- [ ] **Step 2: Run migration**

Run: `mix ecto.migrate`
Expected: Migration succeeds, table created.

Verify with Tidewave: `execute_sql_query(query: "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'program_staff_assignments' ORDER BY ordinal_position")`

- [ ] **Step 3: Write the Ecto schema**

```elixir
defmodule KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProgramStaffAssignmentSchema do
  use Ecto.Schema
  import Ecto.Changeset

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "program_staff_assignments" do
    belongs_to :provider, ProviderProfileSchema
    belongs_to :staff_member, StaffMemberSchema
    field :program_id, :binary_id
    field :assigned_at, :utc_datetime_usec
    field :unassigned_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(provider_id program_id staff_member_id assigned_at)a
  @optional_fields ~w(unassigned_at)a

  def create_changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:provider_id)
    |> foreign_key_constraint(:program_id)
    |> foreign_key_constraint(:staff_member_id)
    |> unique_constraint([:program_id, :staff_member_id],
      name: :program_staff_assignments_active_unique,
      message: "staff member is already assigned to this program"
    )
  end

  def unassign_changeset(schema) do
    schema
    |> change(%{unassigned_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)})
  end
end
```

- [ ] **Step 4: Write schema changeset test**

```elixir
defmodule KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProgramStaffAssignmentSchemaTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProgramStaffAssignmentSchema

  describe "create_changeset/2" do
    test "valid attrs produce valid changeset" do
      attrs = %{
        provider_id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        staff_member_id: Ecto.UUID.generate(),
        assigned_at: DateTime.utc_now()
      }

      changeset = ProgramStaffAssignmentSchema.create_changeset(attrs)
      assert changeset.valid?
    end

    test "missing required fields produce invalid changeset" do
      changeset = ProgramStaffAssignmentSchema.create_changeset(%{})
      refute changeset.valid?
      assert %{provider_id: _, program_id: _, staff_member_id: _, assigned_at: _} = errors_on(changeset)
    end
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/klass_hero/provider/adapters/driven/persistence/schemas/program_staff_assignment_schema_test.exs -v`
Expected: 2 tests pass.

- [ ] **Step 6: Commit**

```bash
git add priv/repo/migrations/*_create_program_staff_assignments.exs lib/klass_hero/provider/adapters/driven/persistence/schemas/program_staff_assignment_schema.ex test/klass_hero/provider/adapters/driven/persistence/schemas/program_staff_assignment_schema_test.exs
git commit -m "feat: add program_staff_assignments table and schema (#361)"
```

---

## Task 2: Provider Context — Domain Model, Port, Mapper, Repository

**Files:**
- Create: `lib/klass_hero/provider/domain/models/program_staff_assignment.ex`
- Create: `lib/klass_hero/provider/domain/ports/for_storing_program_staff_assignments.ex`
- Create: `lib/klass_hero/provider/adapters/driven/persistence/mappers/program_staff_assignment_mapper.ex`
- Create: `lib/klass_hero/provider/adapters/driven/persistence/repositories/program_staff_assignment_repository.ex`
- Modify: `config/config.exs`
- Test: `test/klass_hero/provider/adapters/driven/persistence/repositories/program_staff_assignment_repository_test.exs`

- [ ] **Step 1: Write the domain model**

```elixir
defmodule KlassHero.Provider.Domain.Models.ProgramStaffAssignment do
  @moduledoc """
  Represents an assignment of a staff member to a program.

  An active assignment has `unassigned_at: nil`.
  """

  @enforce_keys [:id, :provider_id, :program_id, :staff_member_id, :assigned_at]

  defstruct [
    :id,
    :provider_id,
    :program_id,
    :staff_member_id,
    :assigned_at,
    :unassigned_at,
    :inserted_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          provider_id: String.t(),
          program_id: String.t(),
          staff_member_id: String.t(),
          assigned_at: DateTime.t(),
          unassigned_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{unassigned_at: nil}), do: true
  def active?(%__MODULE__{}), do: false
end
```

- [ ] **Step 2: Write the driven port**

```elixir
defmodule KlassHero.Provider.Domain.Ports.ForStoringProgramStaffAssignments do
  @moduledoc """
  Port for persisting program-staff assignment data.
  """

  alias KlassHero.Provider.Domain.Models.ProgramStaffAssignment

  @callback create(attrs :: map()) ::
              {:ok, ProgramStaffAssignment.t()} | {:error, :already_assigned | term()}

  @callback unassign(program_id :: String.t(), staff_member_id :: String.t()) ::
              {:ok, ProgramStaffAssignment.t()} | {:error, :not_found}

  @callback list_active_for_program(program_id :: String.t()) :: [ProgramStaffAssignment.t()]

  @callback list_active_for_staff_member(staff_member_id :: String.t()) ::
              [ProgramStaffAssignment.t()]

  @callback list_active_for_provider(provider_id :: String.t()) :: [ProgramStaffAssignment.t()]
end
```

- [ ] **Step 3: Write the mapper**

```elixir
defmodule KlassHero.Provider.Adapters.Driven.Persistence.Mappers.ProgramStaffAssignmentMapper do
  @moduledoc """
  Maps between ProgramStaffAssignmentSchema and ProgramStaffAssignment domain model.
  """

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProgramStaffAssignmentSchema
  alias KlassHero.Provider.Domain.Models.ProgramStaffAssignment

  @spec to_domain(%ProgramStaffAssignmentSchema{}) :: ProgramStaffAssignment.t()
  def to_domain(%ProgramStaffAssignmentSchema{} = schema) do
    %ProgramStaffAssignment{
      id: schema.id,
      provider_id: schema.provider_id,
      program_id: schema.program_id,
      staff_member_id: schema.staff_member_id,
      assigned_at: schema.assigned_at,
      unassigned_at: schema.unassigned_at,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end
```

- [ ] **Step 4: Write the repository test (TDD — test first)**

```elixir
defmodule KlassHero.Provider.Adapters.Driven.Persistence.Repositories.ProgramStaffAssignmentRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Provider.Adapters.Driven.Persistence.Repositories.ProgramStaffAssignmentRepository
  alias KlassHero.Provider.Domain.Models.ProgramStaffAssignment

  describe "create/1" do
    test "creates an active assignment" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff = insert(:staff_member_schema, provider_id: provider.id)

      attrs = %{
        provider_id: provider.id,
        program_id: program.id,
        staff_member_id: staff.id,
        assigned_at: DateTime.utc_now()
      }

      assert {:ok, %ProgramStaffAssignment{} = assignment} =
               ProgramStaffAssignmentRepository.create(attrs)

      assert assignment.provider_id == provider.id
      assert assignment.program_id == program.id
      assert assignment.staff_member_id == staff.id
      assert is_nil(assignment.unassigned_at)
    end

    test "returns already_assigned for duplicate active assignment" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff = insert(:staff_member_schema, provider_id: provider.id)

      attrs = %{
        provider_id: provider.id,
        program_id: program.id,
        staff_member_id: staff.id,
        assigned_at: DateTime.utc_now()
      }

      assert {:ok, _} = ProgramStaffAssignmentRepository.create(attrs)
      assert {:error, :already_assigned} = ProgramStaffAssignmentRepository.create(attrs)
    end
  end

  describe "unassign/2" do
    test "sets unassigned_at on active assignment" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff = insert(:staff_member_schema, provider_id: provider.id)

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider.id,
          program_id: program.id,
          staff_member_id: staff.id,
          assigned_at: DateTime.utc_now()
        })

      assert {:ok, %ProgramStaffAssignment{unassigned_at: unassigned_at}} =
               ProgramStaffAssignmentRepository.unassign(program.id, staff.id)

      refute is_nil(unassigned_at)
    end

    test "returns not_found for non-existent assignment" do
      assert {:error, :not_found} =
               ProgramStaffAssignmentRepository.unassign(
                 Ecto.UUID.generate(),
                 Ecto.UUID.generate()
               )
    end
  end

  describe "list_active_for_program/1" do
    test "returns only active assignments for program" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff1 = insert(:staff_member_schema, provider_id: provider.id)
      staff2 = insert(:staff_member_schema, provider_id: provider.id)

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider.id,
          program_id: program.id,
          staff_member_id: staff1.id,
          assigned_at: DateTime.utc_now()
        })

      {:ok, _} =
        ProgramStaffAssignmentRepository.create(%{
          provider_id: provider.id,
          program_id: program.id,
          staff_member_id: staff2.id,
          assigned_at: DateTime.utc_now()
        })

      # Unassign staff2
      {:ok, _} = ProgramStaffAssignmentRepository.unassign(program.id, staff2.id)

      active = ProgramStaffAssignmentRepository.list_active_for_program(program.id)
      assert length(active) == 1
      assert hd(active).staff_member_id == staff1.id
    end
  end
end
```

- [ ] **Step 5: Run test to verify it fails**

Run: `mix test test/klass_hero/provider/adapters/driven/persistence/repositories/program_staff_assignment_repository_test.exs -v`
Expected: FAIL — module `ProgramStaffAssignmentRepository` not found.

- [ ] **Step 6: Write the repository implementation**

```elixir
defmodule KlassHero.Provider.Adapters.Driven.Persistence.Repositories.ProgramStaffAssignmentRepository do
  @behaviour KlassHero.Provider.Domain.Ports.ForStoringProgramStaffAssignments

  use KlassHero.Shared.Tracing
  import Ecto.Query

  alias KlassHero.Provider.Adapters.Driven.Persistence.Mappers.ProgramStaffAssignmentMapper
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProgramStaffAssignmentSchema
  alias KlassHero.Repo

  @impl true
  def create(attrs) when is_map(attrs) do
    span do
      set_attributes("db", operation: "insert", entity: "program_staff_assignment")

      %ProgramStaffAssignmentSchema{}
      |> ProgramStaffAssignmentSchema.create_changeset(attrs)
      |> Repo.insert()
      |> case do
        {:ok, schema} ->
          {:ok, ProgramStaffAssignmentMapper.to_domain(schema)}

        {:error, %Ecto.Changeset{} = changeset} ->
          if has_unique_constraint_error?(changeset) do
            {:error, :already_assigned}
          else
            {:error, changeset}
          end
      end
    end
  end

  @impl true
  def unassign(program_id, staff_member_id) do
    span do
      set_attributes("db", operation: "update", entity: "program_staff_assignment")

      ProgramStaffAssignmentSchema
      |> where([a], a.program_id == ^program_id and a.staff_member_id == ^staff_member_id and is_nil(a.unassigned_at))
      |> Repo.one()
      |> case do
        nil ->
          {:error, :not_found}

        schema ->
          schema
          |> ProgramStaffAssignmentSchema.unassign_changeset()
          |> Repo.update()
          |> case do
            {:ok, updated} -> {:ok, ProgramStaffAssignmentMapper.to_domain(updated)}
            {:error, changeset} -> {:error, changeset}
          end
      end
    end
  end

  @impl true
  def list_active_for_program(program_id) do
    span do
      set_attributes("db", operation: "select", entity: "program_staff_assignment")

      ProgramStaffAssignmentSchema
      |> where([a], a.program_id == ^program_id and is_nil(a.unassigned_at))
      |> order_by([a], asc: a.assigned_at)
      |> Repo.all()
      |> Enum.map(&ProgramStaffAssignmentMapper.to_domain/1)
    end
  end

  @impl true
  def list_active_for_staff_member(staff_member_id) do
    span do
      set_attributes("db", operation: "select", entity: "program_staff_assignment")

      ProgramStaffAssignmentSchema
      |> where([a], a.staff_member_id == ^staff_member_id and is_nil(a.unassigned_at))
      |> order_by([a], asc: a.assigned_at)
      |> Repo.all()
      |> Enum.map(&ProgramStaffAssignmentMapper.to_domain/1)
    end
  end

  @impl true
  def list_active_for_provider(provider_id) do
    span do
      set_attributes("db", operation: "select", entity: "program_staff_assignment")

      ProgramStaffAssignmentSchema
      |> where([a], a.provider_id == ^provider_id and is_nil(a.unassigned_at))
      |> order_by([a], asc: a.assigned_at)
      |> Repo.all()
      |> Enum.map(&ProgramStaffAssignmentMapper.to_domain/1)
    end
  end

  defp has_unique_constraint_error?(changeset) do
    Enum.any?(changeset.errors, fn
      {_field, {_msg, [constraint: :unique | _]}} -> true
      _ -> false
    end)
  end
end
```

- [ ] **Step 7: Register port in config**

Add to `config/config.exs` under `:provider` config:

```elixir
for_storing_program_staff_assignments:
  KlassHero.Provider.Adapters.Driven.Persistence.Repositories.ProgramStaffAssignmentRepository
```

- [ ] **Step 8: Run test to verify it passes**

Run: `mix test test/klass_hero/provider/adapters/driven/persistence/repositories/program_staff_assignment_repository_test.exs -v`
Expected: All tests pass.

- [ ] **Step 9: Commit**

```bash
git add lib/klass_hero/provider/domain/models/program_staff_assignment.ex lib/klass_hero/provider/domain/ports/for_storing_program_staff_assignments.ex lib/klass_hero/provider/adapters/driven/persistence/mappers/program_staff_assignment_mapper.ex lib/klass_hero/provider/adapters/driven/persistence/repositories/program_staff_assignment_repository.ex config/config.exs test/klass_hero/provider/adapters/driven/persistence/repositories/program_staff_assignment_repository_test.exs
git commit -m "feat: add program staff assignment domain model, port, and repository (#361)"
```

---

## Task 3: Provider Context — Assign/Unassign Use Cases & Integration Events

**Files:**
- Modify: `lib/klass_hero/provider/domain/events/provider_integration_events.ex`
- Modify: `lib/klass_hero/provider/adapters/driving/events/event_handlers/promote_integration_events.ex`
- Create: `lib/klass_hero/provider/application/use_cases/staff_members/assign_staff_to_program.ex`
- Create: `lib/klass_hero/provider/application/use_cases/staff_members/unassign_staff_from_program.ex`
- Modify: `lib/klass_hero/provider.ex`
- Modify: `lib/klass_hero/application.ex`
- Test: `test/klass_hero/provider/application/use_cases/staff_members/assign_staff_to_program_test.exs`
- Test: `test/klass_hero/provider/application/use_cases/staff_members/unassign_staff_from_program_test.exs`

- [ ] **Step 1: Add integration event factory functions**

Add to `lib/klass_hero/provider/domain/events/provider_integration_events.ex`:

```elixir
def staff_assigned_to_program(staff_member_id, payload \\ %{}, opts \\ []) do
  criticality = Keyword.get(opts, :criticality, :critical)

  IntegrationEvent.new(
    :staff_assigned_to_program,
    :provider,
    :staff_member,
    staff_member_id,
    payload,
    metadata: %{criticality: criticality}
  )
end

def staff_unassigned_from_program(staff_member_id, payload \\ %{}, opts \\ []) do
  criticality = Keyword.get(opts, :criticality, :critical)

  IntegrationEvent.new(
    :staff_unassigned_from_program,
    :provider,
    :staff_member,
    staff_member_id,
    payload,
    metadata: %{criticality: criticality}
  )
end
```

- [ ] **Step 2: Add domain event types and promotion handlers**

Add to `lib/klass_hero/provider/domain/events/provider_events.ex` — two new domain event factory functions:

```elixir
def staff_assigned_to_program(assignment, staff_member) do
  DomainEvent.new(
    :staff_assigned_to_program,
    :provider,
    assignment.id,
    %{
      provider_id: assignment.provider_id,
      program_id: assignment.program_id,
      staff_member_id: assignment.staff_member_id,
      staff_user_id: staff_member.user_id,
      assigned_at: assignment.assigned_at
    }
  )
end

def staff_unassigned_from_program(assignment, staff_member) do
  DomainEvent.new(
    :staff_unassigned_from_program,
    :provider,
    assignment.id,
    %{
      provider_id: assignment.provider_id,
      program_id: assignment.program_id,
      staff_member_id: assignment.staff_member_id,
      staff_user_id: staff_member.user_id,
      unassigned_at: assignment.unassigned_at
    }
  )
end
```

Add to `lib/klass_hero/provider/adapters/driving/events/event_handlers/promote_integration_events.ex`:

```elixir
def handle(%DomainEvent{event_type: :staff_assigned_to_program} = event) do
  event.aggregate_id
  |> ProviderIntegrationEvents.staff_assigned_to_program(event.payload)
  |> IntegrationEventPublishing.publish_critical("staff_assigned_to_program",
    staff_member_id: event.payload.staff_member_id
  )
end

def handle(%DomainEvent{event_type: :staff_unassigned_from_program} = event) do
  event.aggregate_id
  |> ProviderIntegrationEvents.staff_unassigned_from_program(event.payload)
  |> IntegrationEventPublishing.publish_critical("staff_unassigned_from_program",
    staff_member_id: event.payload.staff_member_id
  )
end
```

- [ ] **Step 3: Register new domain events on the Provider DomainEventBus**

In `lib/klass_hero/application.ex`, add to the Provider DomainEventBus handler list:

```elixir
{:staff_assigned_to_program,
 {KlassHero.Provider.Adapters.Driving.Events.EventHandlers.PromoteIntegrationEvents,
  :handle}},
{:staff_unassigned_from_program,
 {KlassHero.Provider.Adapters.Driving.Events.EventHandlers.PromoteIntegrationEvents,
  :handle}}
```

- [ ] **Step 4: Write the assign use case test (TDD)**

```elixir
defmodule KlassHero.Provider.Application.UseCases.StaffMembers.AssignStaffToProgramTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Provider.Application.UseCases.StaffMembers.AssignStaffToProgram
  alias KlassHero.Provider.Domain.Models.ProgramStaffAssignment

  describe "execute/1" do
    test "creates assignment and returns domain model" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff = insert(:staff_member_schema, provider_id: provider.id, user_id: Ecto.UUID.generate())

      assert {:ok, %ProgramStaffAssignment{} = assignment} =
               AssignStaffToProgram.execute(%{
                 provider_id: provider.id,
                 program_id: program.id,
                 staff_member_id: staff.id
               })

      assert assignment.provider_id == provider.id
      assert assignment.program_id == program.id
      assert assignment.staff_member_id == staff.id
      assert is_nil(assignment.unassigned_at)
    end

    test "returns already_assigned for duplicate" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff = insert(:staff_member_schema, provider_id: provider.id, user_id: Ecto.UUID.generate())

      attrs = %{provider_id: provider.id, program_id: program.id, staff_member_id: staff.id}

      assert {:ok, _} = AssignStaffToProgram.execute(attrs)
      assert {:error, :already_assigned} = AssignStaffToProgram.execute(attrs)
    end
  end
end
```

- [ ] **Step 5: Run test to verify it fails**

Run: `mix test test/klass_hero/provider/application/use_cases/staff_members/assign_staff_to_program_test.exs -v`
Expected: FAIL — module not found.

- [ ] **Step 6: Write the assign use case**

```elixir
defmodule KlassHero.Provider.Application.UseCases.StaffMembers.AssignStaffToProgram do
  @moduledoc """
  Assigns a staff member to a program.

  Creates the assignment record and publishes a domain event that gets
  promoted to an integration event for cross-context consumption.
  """

  alias KlassHero.Provider.Domain.Events.ProviderEvents
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @context KlassHero.Provider
  @assignment_repo Application.compile_env!(:klass_hero, [
                     :provider,
                     :for_storing_program_staff_assignments
                   ])
  @staff_repo Application.compile_env!(:klass_hero, [:provider, :for_storing_staff_members])

  @spec execute(map()) ::
          {:ok, KlassHero.Provider.Domain.Models.ProgramStaffAssignment.t()}
          | {:error, :already_assigned | :staff_not_found | term()}
  def execute(attrs) when is_map(attrs) do
    with {:ok, staff_member} <- @staff_repo.get(attrs.staff_member_id),
         assignment_attrs <- Map.put(attrs, :assigned_at, DateTime.utc_now()),
         {:ok, assignment} <- @assignment_repo.create(assignment_attrs) do
      publish_event(assignment, staff_member)

      Logger.info("Staff member assigned to program",
        staff_member_id: assignment.staff_member_id,
        program_id: assignment.program_id
      )

      {:ok, assignment}
    end
  end

  defp publish_event(assignment, staff_member) do
    event = ProviderEvents.staff_assigned_to_program(assignment, staff_member)
    DomainEventBus.dispatch(@context, event)
  end
end
```

- [ ] **Step 7: Write the unassign use case test (TDD)**

```elixir
defmodule KlassHero.Provider.Application.UseCases.StaffMembers.UnassignStaffFromProgramTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Provider.Application.UseCases.StaffMembers.AssignStaffToProgram
  alias KlassHero.Provider.Application.UseCases.StaffMembers.UnassignStaffFromProgram
  alias KlassHero.Provider.Domain.Models.ProgramStaffAssignment

  describe "execute/2" do
    test "unassigns active assignment" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff = insert(:staff_member_schema, provider_id: provider.id, user_id: Ecto.UUID.generate())

      {:ok, _} =
        AssignStaffToProgram.execute(%{
          provider_id: provider.id,
          program_id: program.id,
          staff_member_id: staff.id
        })

      assert {:ok, %ProgramStaffAssignment{unassigned_at: unassigned_at}} =
               UnassignStaffFromProgram.execute(program.id, staff.id)

      refute is_nil(unassigned_at)
    end

    test "returns not_found when no active assignment exists" do
      assert {:error, :not_found} =
               UnassignStaffFromProgram.execute(Ecto.UUID.generate(), Ecto.UUID.generate())
    end
  end
end
```

- [ ] **Step 8: Write the unassign use case**

```elixir
defmodule KlassHero.Provider.Application.UseCases.StaffMembers.UnassignStaffFromProgram do
  @moduledoc """
  Unassigns a staff member from a program.

  Sets `unassigned_at` (soft unassign) and publishes a domain event.
  """

  alias KlassHero.Provider.Domain.Events.ProviderEvents
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @context KlassHero.Provider
  @assignment_repo Application.compile_env!(:klass_hero, [
                     :provider,
                     :for_storing_program_staff_assignments
                   ])
  @staff_repo Application.compile_env!(:klass_hero, [:provider, :for_storing_staff_members])

  @spec execute(String.t(), String.t()) ::
          {:ok, KlassHero.Provider.Domain.Models.ProgramStaffAssignment.t()}
          | {:error, :not_found | term()}
  def execute(program_id, staff_member_id) do
    with {:ok, assignment} <- @assignment_repo.unassign(program_id, staff_member_id),
         {:ok, staff_member} <- @staff_repo.get(staff_member_id) do
      publish_event(assignment, staff_member)

      Logger.info("Staff member unassigned from program",
        staff_member_id: staff_member_id,
        program_id: program_id
      )

      {:ok, assignment}
    end
  end

  defp publish_event(assignment, staff_member) do
    event = ProviderEvents.staff_unassigned_from_program(assignment, staff_member)
    DomainEventBus.dispatch(@context, event)
  end
end
```

- [ ] **Step 9: Expose in Provider facade**

Add to `lib/klass_hero/provider.ex`:

```elixir
alias KlassHero.Provider.Application.UseCases.StaffMembers.AssignStaffToProgram
alias KlassHero.Provider.Application.UseCases.StaffMembers.UnassignStaffFromProgram

@spec assign_staff_to_program(map()) ::
        {:ok, ProgramStaffAssignment.t()} | {:error, :already_assigned | term()}
defdelegate assign_staff_to_program(attrs), to: AssignStaffToProgram, as: :execute

@spec unassign_staff_from_program(String.t(), String.t()) ::
        {:ok, ProgramStaffAssignment.t()} | {:error, :not_found | term()}
defdelegate unassign_staff_from_program(program_id, staff_member_id),
  to: UnassignStaffFromProgram,
  as: :execute
```

Also add the model alias and export:

```elixir
alias KlassHero.Provider.Domain.Models.ProgramStaffAssignment
```

- [ ] **Step 10: Add factory for test support**

Add to `test/support/factory.ex`:

```elixir
def staff_member_schema_factory do
  provider = insert(:provider_profile_schema)

  %StaffMemberSchema{
    id: Ecto.UUID.generate(),
    provider_id: provider.id,
    first_name: sequence(:staff_first_name, &"Staff#{&1}"),
    last_name: sequence(:staff_last_name, &"Member#{&1}"),
    role: "Instructor",
    active: true,
    tags: []
  }
end
```

Check if this factory already exists first. If it does, skip this step. If a similar factory exists with a different name, use that name in the tests instead.

- [ ] **Step 11: Run all tests to verify they pass**

Run: `mix test test/klass_hero/provider/application/use_cases/staff_members/assign_staff_to_program_test.exs test/klass_hero/provider/application/use_cases/staff_members/unassign_staff_from_program_test.exs -v`
Expected: All tests pass.

- [ ] **Step 12: Verify events with Tidewave**

Use Tidewave `project_eval` to verify the Provider DomainEventBus has the new handlers registered:

```elixir
project_eval(code: ":sys.get_state(KlassHero.Shared.DomainEventBus.process_name(KlassHero.Provider))")
```

Expected: See `:staff_assigned_to_program` and `:staff_unassigned_from_program` in the handler map.

- [ ] **Step 13: Commit**

```bash
git add lib/klass_hero/provider/domain/events/ lib/klass_hero/provider/application/use_cases/staff_members/assign_staff_to_program.ex lib/klass_hero/provider/application/use_cases/staff_members/unassign_staff_from_program.ex lib/klass_hero/provider/adapters/driving/events/event_handlers/promote_integration_events.ex lib/klass_hero/provider.ex lib/klass_hero/application.ex test/klass_hero/provider/application/use_cases/staff_members/ test/support/factory.ex
git commit -m "feat: add assign/unassign staff use cases with integration events (#361)"
```

> **Note — Staff invitation acceptance backfill:** When a staff member accepts their invitation and gets a `user_id`, the Provider context should re-publish `staff_assigned_to_program` events for all their active assignments. This is handled in the existing `AcceptStaffInvitation` use case (or equivalent) — add a step there to query `list_active_for_staff_member(staff_member_id)` and dispatch events for each. The Messaging handler is idempotent, so duplicate events are safe. Implement this as a follow-up if `AcceptStaffInvitation` exists, or as part of the invitation flow when it's built.

---

## Task 4: Messaging Context — Projection Migration, Schema & Repository

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_program_staff_participants.exs`
- Create: `lib/klass_hero/messaging/adapters/driven/persistence/schemas/program_staff_participant_schema.ex`
- Create: `lib/klass_hero/messaging/domain/ports/for_resolving_program_staff.ex`
- Create: `lib/klass_hero/messaging/adapters/driven/persistence/repositories/program_staff_participant_repository.ex`
- Modify: `config/config.exs`
- Test: `test/klass_hero/messaging/adapters/driven/persistence/repositories/program_staff_participant_repository_test.exs`

- [ ] **Step 1: Write the migration**

```elixir
defmodule KlassHero.Repo.Migrations.CreateProgramStaffParticipants do
  use Ecto.Migration

  def change do
    create table(:program_staff_participants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider_id, :binary_id, null: false
      add :program_id, :binary_id, null: false
      add :staff_user_id, :binary_id, null: false
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:program_staff_participants, [:program_id, :staff_user_id])
    create index(:program_staff_participants, [:provider_id])
    create index(:program_staff_participants, [:staff_user_id])
  end
end
```

Note: No foreign keys — this is a projection table owned by Messaging, populated by events. The source of truth is in the Provider context.

- [ ] **Step 2: Run migration**

Run: `mix ecto.migrate`
Expected: Migration succeeds.

Verify with Tidewave: `execute_sql_query(query: "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'program_staff_participants' ORDER BY ordinal_position")`

- [ ] **Step 3: Write the projection schema**

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ProgramStaffParticipantSchema do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "program_staff_participants" do
    field :provider_id, :binary_id
    field :program_id, :binary_id
    field :staff_user_id, :binary_id
    field :active, :boolean, default: true

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(provider_id program_id staff_user_id)a
  @optional_fields ~w(active)a

  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:program_id, :staff_user_id])
  end
end
```

- [ ] **Step 4: Write the driven port**

```elixir
defmodule KlassHero.Messaging.Domain.Ports.ForResolvingProgramStaff do
  @moduledoc """
  Port for querying the program staff participants projection.

  This projection is kept in sync by integration events from the Provider context.
  It allows Messaging to resolve which staff user IDs are assigned to a program
  without querying the Provider context.
  """

  @doc """
  Returns user IDs of active staff assigned to a program.
  """
  @callback get_active_staff_user_ids(program_id :: String.t()) :: [String.t()]

  @doc """
  Upserts a staff participant projection row. Sets active to true.
  """
  @callback upsert_active(attrs :: map()) :: :ok

  @doc """
  Marks a staff participant as inactive.
  """
  @callback deactivate(program_id :: String.t(), staff_user_id :: String.t()) :: :ok
end
```

- [ ] **Step 5: Write the repository test (TDD)**

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ProgramStaffParticipantRepositoryTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ProgramStaffParticipantRepository

  @provider_id Ecto.UUID.generate()
  @program_id Ecto.UUID.generate()

  describe "upsert_active/1" do
    test "inserts new active staff participant" do
      staff_user_id = Ecto.UUID.generate()

      assert :ok =
               ProgramStaffParticipantRepository.upsert_active(%{
                 provider_id: @provider_id,
                 program_id: @program_id,
                 staff_user_id: staff_user_id
               })

      assert [^staff_user_id] =
               ProgramStaffParticipantRepository.get_active_staff_user_ids(@program_id)
    end

    test "reactivates previously deactivated participant" do
      staff_user_id = Ecto.UUID.generate()

      attrs = %{provider_id: @provider_id, program_id: @program_id, staff_user_id: staff_user_id}

      :ok = ProgramStaffParticipantRepository.upsert_active(attrs)
      :ok = ProgramStaffParticipantRepository.deactivate(@program_id, staff_user_id)

      assert [] = ProgramStaffParticipantRepository.get_active_staff_user_ids(@program_id)

      :ok = ProgramStaffParticipantRepository.upsert_active(attrs)

      assert [^staff_user_id] =
               ProgramStaffParticipantRepository.get_active_staff_user_ids(@program_id)
    end
  end

  describe "deactivate/2" do
    test "marks staff participant as inactive" do
      staff_user_id = Ecto.UUID.generate()

      :ok =
        ProgramStaffParticipantRepository.upsert_active(%{
          provider_id: @provider_id,
          program_id: @program_id,
          staff_user_id: staff_user_id
        })

      :ok = ProgramStaffParticipantRepository.deactivate(@program_id, staff_user_id)

      assert [] = ProgramStaffParticipantRepository.get_active_staff_user_ids(@program_id)
    end

    test "is a no-op for non-existent participant" do
      assert :ok =
               ProgramStaffParticipantRepository.deactivate(
                 Ecto.UUID.generate(),
                 Ecto.UUID.generate()
               )
    end
  end

  describe "get_active_staff_user_ids/1" do
    test "returns only active staff for program" do
      staff1 = Ecto.UUID.generate()
      staff2 = Ecto.UUID.generate()

      :ok = ProgramStaffParticipantRepository.upsert_active(%{provider_id: @provider_id, program_id: @program_id, staff_user_id: staff1})
      :ok = ProgramStaffParticipantRepository.upsert_active(%{provider_id: @provider_id, program_id: @program_id, staff_user_id: staff2})
      :ok = ProgramStaffParticipantRepository.deactivate(@program_id, staff2)

      active = ProgramStaffParticipantRepository.get_active_staff_user_ids(@program_id)
      assert active == [staff1]
    end
  end
end
```

- [ ] **Step 6: Run test to verify it fails**

Run: `mix test test/klass_hero/messaging/adapters/driven/persistence/repositories/program_staff_participant_repository_test.exs -v`
Expected: FAIL — module not found.

- [ ] **Step 7: Write the repository implementation**

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ProgramStaffParticipantRepository do
  @behaviour KlassHero.Messaging.Domain.Ports.ForResolvingProgramStaff

  use KlassHero.Shared.Tracing
  import Ecto.Query

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ProgramStaffParticipantSchema
  alias KlassHero.Repo

  @impl true
  def get_active_staff_user_ids(program_id) do
    span do
      set_attributes("db", operation: "select", entity: "program_staff_participant")

      ProgramStaffParticipantSchema
      |> where([p], p.program_id == ^program_id and p.active == true)
      |> select([p], p.staff_user_id)
      |> Repo.all()
    end
  end

  @impl true
  def upsert_active(attrs) do
    span do
      set_attributes("db", operation: "upsert", entity: "program_staff_participant")

      %ProgramStaffParticipantSchema{}
      |> ProgramStaffParticipantSchema.changeset(Map.put(attrs, :active, true))
      |> Repo.insert!(
        on_conflict: [set: [active: true, updated_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)]],
        conflict_target: [:program_id, :staff_user_id]
      )

      :ok
    end
  end

  @impl true
  def deactivate(program_id, staff_user_id) do
    span do
      set_attributes("db", operation: "update", entity: "program_staff_participant")

      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      from(p in ProgramStaffParticipantSchema,
        where: p.program_id == ^program_id and p.staff_user_id == ^staff_user_id
      )
      |> Repo.update_all(set: [active: false, updated_at: now])

      :ok
    end
  end
end
```

- [ ] **Step 8: Register port in config**

Add to `config/config.exs` under `:messaging` config:

```elixir
for_resolving_program_staff:
  KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ProgramStaffParticipantRepository
```

- [ ] **Step 9: Run test to verify it passes**

Run: `mix test test/klass_hero/messaging/adapters/driven/persistence/repositories/program_staff_participant_repository_test.exs -v`
Expected: All tests pass.

- [ ] **Step 10: Commit**

```bash
git add priv/repo/migrations/*_create_program_staff_participants.exs lib/klass_hero/messaging/adapters/driven/persistence/schemas/program_staff_participant_schema.ex lib/klass_hero/messaging/domain/ports/for_resolving_program_staff.ex lib/klass_hero/messaging/adapters/driven/persistence/repositories/program_staff_participant_repository.ex config/config.exs test/klass_hero/messaging/adapters/driven/persistence/repositories/program_staff_participant_repository_test.exs
git commit -m "feat: add messaging projection for program staff participants (#361)"
```

---

## Task 5: Messaging Context — Integration Event Handler

**Files:**
- Create: `lib/klass_hero/messaging/adapters/driving/events/staff_assignment_handler.ex`
- Modify: `lib/klass_hero/application.ex`
- Test: `test/klass_hero/messaging/adapters/driving/events/staff_assignment_handler_test.exs`

- [ ] **Step 1: Write the event handler test (TDD)**

```elixir
defmodule KlassHero.Messaging.Adapters.Driving.Events.StaffAssignmentHandlerTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ProgramStaffParticipantRepository
  alias KlassHero.Messaging.Adapters.Driving.Events.StaffAssignmentHandler
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  describe "handle_event/1 - staff_assigned_to_program" do
    test "upserts projection when staff_user_id is present" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff_user_id = Ecto.UUID.generate()

      event = %IntegrationEvent{
        event_id: Ecto.UUID.generate(),
        event_type: :staff_assigned_to_program,
        source_context: :provider,
        entity_type: :staff_member,
        entity_id: Ecto.UUID.generate(),
        occurred_at: DateTime.utc_now(),
        payload: %{
          provider_id: provider.id,
          program_id: program.id,
          staff_member_id: Ecto.UUID.generate(),
          staff_user_id: staff_user_id,
          assigned_at: DateTime.utc_now()
        }
      }

      assert :ok = StaffAssignmentHandler.handle_event(event)

      assert [^staff_user_id] =
               ProgramStaffParticipantRepository.get_active_staff_user_ids(program.id)
    end

    test "skips when staff_user_id is nil" do
      event = %IntegrationEvent{
        event_id: Ecto.UUID.generate(),
        event_type: :staff_assigned_to_program,
        source_context: :provider,
        entity_type: :staff_member,
        entity_id: Ecto.UUID.generate(),
        occurred_at: DateTime.utc_now(),
        payload: %{
          provider_id: Ecto.UUID.generate(),
          program_id: Ecto.UUID.generate(),
          staff_member_id: Ecto.UUID.generate(),
          staff_user_id: nil,
          assigned_at: DateTime.utc_now()
        }
      }

      assert :ok = StaffAssignmentHandler.handle_event(event)
    end

    test "adds staff to existing active conversations for the program" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      parent_user = KlassHero.AccountsFixtures.user_fixture()
      staff_user_id = Ecto.UUID.generate()

      # Create an existing conversation for this program
      conversation = insert(:conversation_schema,
        provider_id: provider.id,
        type: "direct",
        program_id: program.id
      )

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: parent_user.id
      )

      event = %IntegrationEvent{
        event_id: Ecto.UUID.generate(),
        event_type: :staff_assigned_to_program,
        source_context: :provider,
        entity_type: :staff_member,
        entity_id: Ecto.UUID.generate(),
        occurred_at: DateTime.utc_now(),
        payload: %{
          provider_id: provider.id,
          program_id: program.id,
          staff_member_id: Ecto.UUID.generate(),
          staff_user_id: staff_user_id,
          assigned_at: DateTime.utc_now()
        }
      }

      assert :ok = StaffAssignmentHandler.handle_event(event)

      # Staff should now be a participant
      assert KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ParticipantRepository.is_participant?(
               conversation.id,
               staff_user_id
             )
    end
  end

  describe "handle_event/1 - staff_unassigned_from_program" do
    test "deactivates projection entry" do
      provider_id = Ecto.UUID.generate()
      program_id = Ecto.UUID.generate()
      staff_user_id = Ecto.UUID.generate()

      ProgramStaffParticipantRepository.upsert_active(%{
        provider_id: provider_id,
        program_id: program_id,
        staff_user_id: staff_user_id
      })

      event = %IntegrationEvent{
        event_id: Ecto.UUID.generate(),
        event_type: :staff_unassigned_from_program,
        source_context: :provider,
        entity_type: :staff_member,
        entity_id: Ecto.UUID.generate(),
        occurred_at: DateTime.utc_now(),
        payload: %{
          provider_id: provider_id,
          program_id: program_id,
          staff_member_id: Ecto.UUID.generate(),
          staff_user_id: staff_user_id,
          unassigned_at: DateTime.utc_now()
        }
      }

      assert :ok = StaffAssignmentHandler.handle_event(event)

      assert [] = ProgramStaffParticipantRepository.get_active_staff_user_ids(program_id)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/messaging/adapters/driving/events/staff_assignment_handler_test.exs -v`
Expected: FAIL — module not found.

- [ ] **Step 3: Write the event handler**

```elixir
defmodule KlassHero.Messaging.Adapters.Driving.Events.StaffAssignmentHandler do
  @moduledoc """
  Handles Provider integration events for staff-program assignment changes.

  On assignment: upserts projection + adds staff to existing conversations.
  On unassignment: deactivates projection (does NOT remove from conversations).
  """

  @behaviour KlassHero.Shared.Domain.Ports.Driving.ForHandlingIntegrationEvents

  import Ecto.Query

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSchema
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ParticipantSchema
  alias KlassHero.Repo
  alias KlassHero.Shared.Adapters.Driven.Events.RetryHelpers

  require Logger

  @staff_projection Application.compile_env!(:klass_hero, [
                      :messaging,
                      :for_resolving_program_staff
                    ])
  @participant_repo Application.compile_env!(:klass_hero, [:messaging, :for_managing_participants])

  @impl true
  def subscribed_events, do: [:staff_assigned_to_program, :staff_unassigned_from_program]

  @impl true
  def handle_event(%{event_type: :staff_assigned_to_program, payload: payload}) do
    staff_user_id = Map.get(payload, :staff_user_id)

    if is_nil(staff_user_id) do
      Logger.debug("Skipping staff assignment — no user_id yet",
        staff_member_id: payload.staff_member_id
      )

      :ok
    else
      handle_assignment_with_retry(payload)
    end
  end

  def handle_event(%{event_type: :staff_unassigned_from_program, payload: payload}) do
    handle_unassignment_with_retry(payload)
  end

  def handle_event(_event), do: :ignore

  defp handle_assignment_with_retry(payload) do
    operation = fn ->
      # 1. Upsert projection
      @staff_projection.upsert_active(%{
        provider_id: payload.provider_id,
        program_id: payload.program_id,
        staff_user_id: payload.staff_user_id
      })

      # 2. Add staff to existing active conversations for this program
      add_staff_to_existing_conversations(payload.program_id, payload.staff_user_id)

      :ok
    end

    context = %{
      operation_name: "handle staff assignment",
      aggregate_id: payload.staff_member_id,
      backoff_ms: 100
    }

    RetryHelpers.retry_and_normalize(operation, context)
  end

  defp handle_unassignment_with_retry(payload) do
    operation = fn ->
      @staff_projection.deactivate(payload.program_id, payload.staff_user_id)
      :ok
    end

    context = %{
      operation_name: "handle staff unassignment",
      aggregate_id: payload.staff_member_id,
      backoff_ms: 100
    }

    RetryHelpers.retry_and_normalize(operation, context)
  end

  defp add_staff_to_existing_conversations(program_id, staff_user_id) do
    # Find all active conversations for this program where staff is not yet a participant
    conversation_ids =
      from(c in ConversationSchema,
        where: c.program_id == ^program_id and is_nil(c.archived_at),
        left_join: p in ParticipantSchema,
        on: p.conversation_id == c.id and p.user_id == ^staff_user_id,
        where: is_nil(p.id),
        select: c.id
      )
      |> Repo.all()

    Enum.each(conversation_ids, fn conversation_id ->
      case @participant_repo.add(%{
             conversation_id: conversation_id,
             user_id: staff_user_id,
             joined_at: DateTime.utc_now()
           }) do
        {:ok, _} ->
          Logger.debug("Added staff to conversation",
            conversation_id: conversation_id,
            staff_user_id: staff_user_id
          )

        {:error, :already_participant} ->
          :ok

        {:error, reason} ->
          Logger.warning("Failed to add staff to conversation",
            conversation_id: conversation_id,
            staff_user_id: staff_user_id,
            reason: inspect(reason)
          )
      end
    end)
  end
end
```

- [ ] **Step 4: Register subscriber in application.ex**

Add a new `EventSubscriber` child spec in `lib/klass_hero/application.ex`:

```elixir
Supervisor.child_spec(
  {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
   handler: KlassHero.Messaging.Adapters.Driving.Events.StaffAssignmentHandler,
   topics: [
     "integration:provider:staff_assigned_to_program",
     "integration:provider:staff_unassigned_from_program"
   ],
   message_tag: :integration_event,
   event_label: "Integration event"},
  id: :messaging_staff_assignment_subscriber
),
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/klass_hero/messaging/adapters/driving/events/staff_assignment_handler_test.exs -v`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/messaging/adapters/driving/events/staff_assignment_handler.ex lib/klass_hero/application.ex test/klass_hero/messaging/adapters/driving/events/staff_assignment_handler_test.exs
git commit -m "feat: add messaging event handler for staff assignment changes (#361)"
```

---

## Task 6: Modify Conversation Creation Use Cases

**Files:**
- Modify: `lib/klass_hero/messaging/application/use_cases/create_direct_conversation.ex`
- Modify: `lib/klass_hero/messaging/application/use_cases/broadcast_to_program.ex`
- Test: `test/klass_hero/messaging/application/use_cases/create_direct_conversation_test.exs` (add test)
- Test: `test/klass_hero/messaging/application/use_cases/broadcast_to_program_test.exs` (add test)

- [ ] **Step 1: Write failing test for CreateDirectConversation**

Add to the existing test file `test/klass_hero/messaging/application/use_cases/create_direct_conversation_test.exs`:

```elixir
describe "staff auto-inclusion" do
  test "adds assigned staff as participants when conversation has program context" do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id)
    scope = build_scope_with_provider(provider, :professional)
    target_user = AccountsFixtures.user_fixture()
    staff_user_id = Ecto.UUID.generate()

    # Seed projection: staff is assigned to this program
    KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ProgramStaffParticipantRepository.upsert_active(%{
      provider_id: provider.id,
      program_id: program.id,
      staff_user_id: staff_user_id
    })

    assert {:ok, conversation} =
             CreateDirectConversation.execute(scope, provider.id, target_user.id,
               program_id: program.id
             )

    # Verify staff was added as participant
    assert KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ParticipantRepository.is_participant?(
             conversation.id,
             staff_user_id
           )
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/messaging/application/use_cases/create_direct_conversation_test.exs --only describe:"staff auto-inclusion" -v`
Expected: FAIL — staff not added as participant.

- [ ] **Step 3: Modify CreateDirectConversation to include staff**

In `create_direct_conversation.ex`, add after the participants are added in `create_new_conversation/3`:

```elixir
@staff_resolver Application.compile_env!(:klass_hero, [:messaging, :for_resolving_program_staff])

# In the execute function, pass opts through:
defp create_new_conversation(scope, provider_id, target_user_id, opts) do
  program_id = Keyword.get(opts, :program_id)

  Repo.transaction(fn ->
    attrs = %{type: :direct, provider_id: provider_id, program_id: program_id}

    with {:ok, conversation} <- @conversation_repo.create(attrs),
         :ok <- add_participants(conversation.id, scope.user.id, target_user_id),
         :ok <- add_assigned_staff(conversation.id, program_id, scope.user.id) do
      participant_ids = [scope.user.id, target_user_id]
      publish_event(conversation, participant_ids, provider_id)
      conversation
    else
      {:error, reason} -> Repo.rollback(reason)
    end
  end)
end

defp add_assigned_staff(_conversation_id, nil, _owner_user_id), do: :ok

defp add_assigned_staff(conversation_id, program_id, owner_user_id) do
  staff_user_ids = @staff_resolver.get_active_staff_user_ids(program_id)

  # Exclude the owner — they're already a participant
  new_staff_ids = Enum.reject(staff_user_ids, &(&1 == owner_user_id))

  if new_staff_ids != [] do
    {:ok, _} = @participant_repo.add_batch(conversation_id, new_staff_ids)
  end

  :ok
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/messaging/application/use_cases/create_direct_conversation_test.exs -v`
Expected: All tests pass (new + existing).

- [ ] **Step 5: Write failing test for BroadcastToProgram**

Add to the existing test file:

```elixir
describe "staff auto-inclusion in broadcast" do
  test "adds assigned staff as participants alongside parents" do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id)
    scope = build_scope_with_provider(provider, :professional)
    staff_user_id = Ecto.UUID.generate()

    # Create enrollment
    parent = insert_enrolled_parent(program)

    # Seed projection
    KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ProgramStaffParticipantRepository.upsert_active(%{
      provider_id: provider.id,
      program_id: program.id,
      staff_user_id: staff_user_id
    })

    assert {:ok, conversation, _message, _count} =
             KlassHero.Messaging.broadcast_to_program(scope, program.id, "Hello parents!")

    assert KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ParticipantRepository.is_participant?(
             conversation.id,
             staff_user_id
           )
  end
end
```

Note: The exact factory helper for enrolled parents (`insert_enrolled_parent`) needs to match the existing test patterns. Check the existing broadcast test file for the helper and adjust accordingly.

- [ ] **Step 6: Modify BroadcastToProgram to include staff**

In `broadcast_to_program.ex`, add to `execute_broadcast_transaction/4` after adding parent and provider participants:

```elixir
@staff_resolver Application.compile_env!(:klass_hero, [:messaging, :for_resolving_program_staff])

defp execute_broadcast_transaction(conversation, scope, content, parent_user_ids) do
  Repo.transaction(fn ->
    with {:ok, _participants} <- @participant_repo.add_batch(conversation.id, parent_user_ids),
         {:ok, _} <- @participant_repo.add(%{conversation_id: conversation.id, user_id: scope.user.id}),
         :ok <- add_assigned_staff(conversation.id, conversation.program_id, scope.user.id),
         {:ok, message} <- @message_repo.create(%{
           conversation_id: conversation.id,
           sender_id: scope.user.id,
           content: String.trim(content),
           message_type: :text
         }) do
      {conversation, message}
    else
      {:error, reason} -> Repo.rollback(reason)
    end
  end)
end

defp add_assigned_staff(conversation_id, program_id, owner_user_id) do
  staff_user_ids = @staff_resolver.get_active_staff_user_ids(program_id)
  new_staff_ids = Enum.reject(staff_user_ids, &(&1 == owner_user_id))

  if new_staff_ids != [] do
    {:ok, _} = @participant_repo.add_batch(conversation_id, new_staff_ids)
  end

  :ok
end
```

- [ ] **Step 7: Run both test files**

Run: `mix test test/klass_hero/messaging/application/use_cases/create_direct_conversation_test.exs test/klass_hero/messaging/application/use_cases/broadcast_to_program_test.exs -v`
Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/klass_hero/messaging/application/use_cases/create_direct_conversation.ex lib/klass_hero/messaging/application/use_cases/broadcast_to_program.ex test/klass_hero/messaging/application/use_cases/
git commit -m "feat: auto-include assigned staff in new conversations (#361)"
```

---

## Task 7: Modify SendMessage — Allow Staff to Send in Broadcasts

**Files:**
- Modify: `lib/klass_hero/messaging/application/use_cases/send_message.ex`
- Test: `test/klass_hero/messaging/application/use_cases/send_message_test.exs` (add test)

- [ ] **Step 1: Write failing test**

Add to the existing send_message test file:

```elixir
describe "broadcast send permission for staff" do
  test "allows provider-side staff to send in broadcast" do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id)
    staff_user_id = Ecto.UUID.generate()

    conversation = insert(:broadcast_conversation_schema,
      provider_id: provider.id,
      program_id: program.id
    )

    insert(:participant_schema, conversation_id: conversation.id, user_id: staff_user_id)

    # Seed projection so staff is recognized as provider-side
    KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ProgramStaffParticipantRepository.upsert_active(%{
      provider_id: provider.id,
      program_id: program.id,
      staff_user_id: staff_user_id
    })

    assert {:ok, _message} =
             KlassHero.Messaging.send_message(conversation.id, staff_user_id, "Hello from staff!")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run the specific test. Expected: FAIL — `:broadcast_reply_not_allowed`.

- [ ] **Step 3: Modify verify_broadcast_send_permission**

In `send_message.ex`, update `verify_broadcast_send_permission/3` to also allow staff:

```elixir
@staff_resolver Application.compile_env!(:klass_hero, [:messaging, :for_resolving_program_staff])

defp verify_broadcast_send_permission(conversation_id, sender_id, conversation) do
  result =
    if conversation && conversation.id == conversation_id,
      do: {:ok, conversation},
      else: @conversation_repo.get_by_id(conversation_id)

  case result do
    {:ok, %{type: :program_broadcast, provider_id: provider_id, program_id: program_id}} ->
      cond do
        provider_owner?(provider_id, sender_id) -> :ok
        staff_assigned?(program_id, sender_id) -> :ok
        true -> {:error, :broadcast_reply_not_allowed}
      end

    {:ok, _direct_conversation} ->
      :ok

    {:error, :not_found} ->
      {:error, :not_found}
  end
end

defp provider_owner?(provider_id, sender_id) do
  case @user_resolver.get_user_id_for_provider(provider_id) do
    {:ok, ^sender_id} -> true
    _ -> false
  end
end

defp staff_assigned?(nil, _sender_id), do: false

defp staff_assigned?(program_id, sender_id) do
  staff_user_ids = @staff_resolver.get_active_staff_user_ids(program_id)
  sender_id in staff_user_ids
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/messaging/application/use_cases/send_message_test.exs -v`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/messaging/application/use_cases/send_message.ex test/klass_hero/messaging/application/use_cases/send_message_test.exs
git commit -m "feat: allow assigned staff to send in broadcast conversations (#361)"
```

---

## Task 8: Web Layer — Provider-Branded Message Attribution

**Files:**
- Modify: `lib/klass_hero_web/live/messaging_live_helper.ex`
- Modify: `lib/klass_hero_web/components/messaging_components.ex`
- Test: Verify visually via Tidewave/Playwright

- [ ] **Step 1: Modify MessagingLiveHelper to resolve provider_user_ids**

In `mount_conversation_show/3`, after loading the conversation, resolve the set of provider-side user IDs:

```elixir
@staff_resolver Application.compile_env!(:klass_hero, [:messaging, :for_resolving_program_staff])

# Inside the success case of mount_conversation_show, add:
provider_user_ids = resolve_provider_user_ids(conversation)

socket =
  socket
  |> assign(:provider_user_ids, provider_user_ids)
  |> assign(:provider_name, resolve_provider_name(conversation.provider_id))
  # ... existing assigns
```

Add helpers:

```elixir
defp resolve_provider_user_ids(conversation) do
  owner_id =
    case Messaging.get_provider_owner_user_id(conversation.provider_id) do
      {:ok, id} -> [id]
      _ -> []
    end

  staff_ids =
    if conversation.program_id do
      @staff_resolver.get_active_staff_user_ids(conversation.program_id)
    else
      []
    end

  MapSet.new(owner_id ++ staff_ids)
end

defp resolve_provider_name(provider_id) do
  case KlassHero.Provider.get_provider(provider_id) do
    {:ok, provider} -> provider.business_name
    _ -> nil
  end
end
```

- [ ] **Step 2: Expose get_provider_owner_user_id in Messaging facade**

Add to `lib/klass_hero/messaging.ex`:

```elixir
@spec get_provider_owner_user_id(String.t()) :: {:ok, String.t()} | {:error, :not_found}
def get_provider_owner_user_id(provider_id) do
  @user_resolver = Application.compile_env!(:klass_hero, [:messaging, :for_resolving_users])
  @user_resolver.get_user_id_for_provider(provider_id)
end
```

Note: Check if `get_user_id_for_provider` already exists on the facade. If so, use the existing function.

- [ ] **Step 3: Modify message_bubble component for provider attribution**

In `messaging_components.ex`, update `message_bubble/1`:

```heex
attr :provider_name, :string, default: nil
attr :is_provider_side, :boolean, default: false

# In the bubble, replace the sender name line:
<p :if={!@is_own && @message.message_type != :system} class="text-xs font-medium mb-1">
  <%= if @is_provider_side && @provider_name do %>
    <span>{@provider_name}</span>
    <span class="text-muted font-normal"> via {@sender_name}</span>
  <% else %>
    {@sender_name}
  <% end %>
</p>
```

- [ ] **Step 4: Pass new attrs from conversation_show component**

In the `conversation_show` component (or wherever messages are rendered), pass the new attrs:

```heex
<.message_bubble
  :for={{id, message} <- @streams.messages}
  id={id}
  message={message}
  is_own={message.sender_id == @current_user_id}
  sender_name={Map.get(@sender_names, message.sender_id, "Unknown")}
  provider_name={@provider_name}
  is_provider_side={MapSet.member?(@provider_user_ids, message.sender_id)}
/>
```

- [ ] **Step 5: Verify via Tidewave**

Use Tidewave `project_eval` to verify the component compiles:

```elixir
project_eval(code: "Code.ensure_compiled(KlassHeroWeb.MessagingComponents)")
```

- [ ] **Step 6: Run mix precommit to check for warnings**

Run: `mix compile --warnings-as-errors`
Expected: No warnings.

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero_web/live/messaging_live_helper.ex lib/klass_hero_web/components/messaging_components.ex lib/klass_hero/messaging.ex
git commit -m "feat: show provider-branded message attribution with staff names (#361)"
```

---

## Task 9: Integration Test — Full End-to-End Flow

**Files:**
- Create: `test/klass_hero/messaging/staff_messaging_integration_test.exs`

- [ ] **Step 1: Write the integration test**

```elixir
defmodule KlassHero.Messaging.StaffMessagingIntegrationTest do
  @moduledoc """
  End-to-end integration test for the staff messaging feature.

  Verifies the full flow: assign staff → staff added to conversations →
  staff can send messages → unassign doesn't remove from existing threads.
  """
  use KlassHero.DataCase, async: false

  import KlassHero.Factory

  alias KlassHero.AccountsFixtures
  alias KlassHero.Messaging
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ParticipantRepository
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ProgramStaffParticipantRepository
  alias KlassHero.Provider

  describe "staff messaging end-to-end" do
    setup do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      provider_user = KlassHero.Repo.get!(KlassHero.Accounts.User, provider.identity_id)
      staff_user = AccountsFixtures.user_fixture()
      parent_user = AccountsFixtures.user_fixture()
      staff = insert(:staff_member_schema, provider_id: provider.id, user_id: staff_user.id)

      %{
        provider: provider,
        program: program,
        provider_user: provider_user,
        staff_user: staff_user,
        parent_user: parent_user,
        staff: staff
      }
    end

    test "full flow: assign → participate → send → unassign", ctx do
      # 1. Assign staff to program
      assert {:ok, assignment} =
               Provider.assign_staff_to_program(%{
                 provider_id: ctx.provider.id,
                 program_id: ctx.program.id,
                 staff_member_id: ctx.staff.id
               })

      # 2. Verify projection was populated
      staff_ids = ProgramStaffParticipantRepository.get_active_staff_user_ids(ctx.program.id)
      assert ctx.staff_user.id in staff_ids

      # 3. Create a conversation — staff should be auto-added
      scope = build_provider_scope(ctx.provider, ctx.provider_user)

      {:ok, conversation} =
        Messaging.create_direct_conversation(scope, ctx.provider.id, ctx.parent_user.id,
          program_id: ctx.program.id
        )

      assert ParticipantRepository.is_participant?(conversation.id, ctx.staff_user.id)

      # 4. Staff can send a message
      assert {:ok, message} =
               Messaging.send_message(conversation.id, ctx.staff_user.id, "Hello from staff!")

      assert message.content == "Hello from staff!"

      # 5. Unassign staff
      assert {:ok, _} =
               Provider.unassign_staff_from_program(ctx.program.id, ctx.staff.id)

      # 6. Staff is still a participant in the existing conversation (soft unassign)
      assert ParticipantRepository.is_participant?(conversation.id, ctx.staff_user.id)

      # 7. But projection is deactivated
      assert [] = ProgramStaffParticipantRepository.get_active_staff_user_ids(ctx.program.id)
    end
  end

  defp build_provider_scope(provider_schema, user) do
    provider_profile = %KlassHero.Provider.Domain.Models.ProviderProfile{
      id: provider_schema.id,
      identity_id: user.id,
      business_name: provider_schema.business_name,
      subscription_tier: :professional
    }

    %KlassHero.Accounts.Scope{
      user: user,
      roles: [:provider],
      provider: provider_profile,
      parent: nil
    }
  end
end
```

- [ ] **Step 2: Run the integration test**

Run: `mix test test/klass_hero/messaging/staff_messaging_integration_test.exs -v`
Expected: All steps pass.

- [ ] **Step 3: Run full test suite**

Run: `mix precommit`
Expected: All compilation, formatting, and tests pass.

- [ ] **Step 4: Commit**

```bash
git add test/klass_hero/messaging/staff_messaging_integration_test.exs
git commit -m "test: add end-to-end integration test for staff messaging (#361)"
```

---

## Task 10: Conversation Summaries Projection — Staff Participant Support

**Files:**
- Modify: `lib/klass_hero/messaging/adapters/driven/projections/conversation_summaries.ex`
- Test: `test/klass_hero/messaging/adapters/driven/projections/conversation_summaries_test.exs` (add test)

- [ ] **Step 1: Write failing test for staff summary rows**

Add to the existing projection test file:

```elixir
describe "staff participant summaries" do
  test "bootstrap creates summary rows for staff participants" do
    # Setup: conversation with provider, parent, and staff participants
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id)
    parent_user = KlassHero.AccountsFixtures.user_fixture()
    staff_user = KlassHero.AccountsFixtures.user_fixture()

    conversation = insert(:conversation_schema,
      provider_id: provider.id,
      type: "direct",
      program_id: program.id
    )

    insert(:participant_schema, conversation_id: conversation.id, user_id: provider.identity_id)
    insert(:participant_schema, conversation_id: conversation.id, user_id: parent_user.id)
    insert(:participant_schema, conversation_id: conversation.id, user_id: staff_user.id)

    # Rebuild projection
    ConversationSummaries.rebuild()

    # Staff should have a summary row
    summaries = list_summaries_for_user(staff_user.id)
    assert length(summaries) == 1
    assert hd(summaries).conversation_id == conversation.id
  end
end
```

- [ ] **Step 2: Run test to verify behavior**

The existing projection bootstrap already handles multi-participant conversations. This test should pass because the bootstrap creates rows for all active participants, regardless of their role. If it passes, no changes needed to the projection — staff are just regular participants.

Run: `mix test test/klass_hero/messaging/adapters/driven/projections/conversation_summaries_test.exs -v`

If it passes: the projection already handles staff correctly. Move to step 4.
If it fails: investigate and adjust the `resolve_other_participant_name` logic.

- [ ] **Step 3: (If needed) Adjust other_participant_name resolution**

The existing logic for direct conversations shows the "other" participant's name. With 3+ participants (owner, parent, staff), the `other_name` resolution needs to pick the right name. For staff rows, the "other" should be the parent's name.

This may need a small adjustment to handle multi-participant direct conversations. The existing code assumes 2 participants for direct — with staff added, there may be 3+.

- [ ] **Step 4: Commit (if changes were needed)**

```bash
git add lib/klass_hero/messaging/adapters/driven/projections/conversation_summaries.ex test/klass_hero/messaging/adapters/driven/projections/conversation_summaries_test.exs
git commit -m "feat: ensure conversation summaries projection handles staff participants (#361)"
```

---

## Task 11: Final Verification & Cleanup

- [ ] **Step 1: Run full precommit suite**

Run: `mix precommit`
Expected: Zero warnings, all tests pass, code formatted.

- [ ] **Step 2: Verify with Tidewave — assignment flow**

```elixir
project_eval(code: """
  # Create test data
  alias KlassHero.Provider
  provider = KlassHero.Repo.one!(KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema)
  programs = KlassHero.Repo.all(KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema)
  staff = KlassHero.Repo.all(KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchema)

  %{
    provider_count: 1,
    program_count: length(programs),
    staff_count: length(staff)
  }
""")
```

- [ ] **Step 3: Verify projection table exists**

```
execute_sql_query(query: "SELECT count(*) FROM program_staff_participants")
execute_sql_query(query: "SELECT count(*) FROM program_staff_assignments")
```

- [ ] **Step 4: Commit any final adjustments**

```bash
git add -A
git commit -m "chore: final cleanup for staff messaging feature (#361)"
```
