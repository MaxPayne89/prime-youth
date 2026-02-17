# Enrollment Capacity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add enrollment capacity (min/max) owned by the enrollment context, remove `spots_available` from program catalog, wire up provider form and booking flow.

**Architecture:** EnrollmentPolicy domain model in enrollment context. New `enrollment_policies` table. ACL in program catalog queries enrollment for remaining capacity. Provider form saves to both contexts.

**Tech Stack:** Elixir/Phoenix, Ecto, LiveView, Ports & Adapters DDD

---

## Task 1: EnrollmentPolicy Domain Model

**Files:**
- Create: `lib/klass_hero/enrollment/domain/models/enrollment_policy.ex`
- Test: `test/klass_hero/enrollment/domain/models/enrollment_policy_test.exs`

**Step 1: Write the failing test**

```elixir
# test/klass_hero/enrollment/domain/models/enrollment_policy_test.exs
defmodule KlassHero.Enrollment.Domain.Models.EnrollmentPolicyTest do
  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Domain.Models.EnrollmentPolicy

  describe "new/1" do
    test "creates policy with valid min and max" do
      assert {:ok, policy} =
               EnrollmentPolicy.new(%{
                 program_id: "prog-123",
                 min_enrollment: 5,
                 max_enrollment: 20
               })

      assert policy.program_id == "prog-123"
      assert policy.min_enrollment == 5
      assert policy.max_enrollment == 20
    end

    test "creates policy with only max" do
      assert {:ok, policy} =
               EnrollmentPolicy.new(%{program_id: "prog-123", max_enrollment: 20})

      assert policy.min_enrollment == nil
      assert policy.max_enrollment == 20
    end

    test "creates policy with only min" do
      assert {:ok, policy} =
               EnrollmentPolicy.new(%{program_id: "prog-123", min_enrollment: 5})

      assert policy.min_enrollment == 5
      assert policy.max_enrollment == nil
    end

    test "rejects when min > max" do
      assert {:error, errors} =
               EnrollmentPolicy.new(%{
                 program_id: "prog-123",
                 min_enrollment: 25,
                 max_enrollment: 10
               })

      assert "minimum enrollment must not exceed maximum enrollment" in errors
    end

    test "rejects when min < 1" do
      assert {:error, errors} =
               EnrollmentPolicy.new(%{program_id: "prog-123", min_enrollment: 0})

      assert "minimum enrollment must be at least 1" in errors
    end

    test "rejects when max < 1" do
      assert {:error, errors} =
               EnrollmentPolicy.new(%{program_id: "prog-123", max_enrollment: 0})

      assert "maximum enrollment must be at least 1" in errors
    end

    test "rejects when neither min nor max is set" do
      assert {:error, errors} = EnrollmentPolicy.new(%{program_id: "prog-123"})
      assert "at least one of minimum or maximum enrollment is required" in errors
    end

    test "rejects missing program_id" do
      assert {:error, errors} = EnrollmentPolicy.new(%{max_enrollment: 20})
      assert "program ID is required" in errors
    end
  end

  describe "has_capacity?/2" do
    test "returns true when count < max" do
      {:ok, policy} = EnrollmentPolicy.new(%{program_id: "p", max_enrollment: 10})
      assert EnrollmentPolicy.has_capacity?(policy, 5) == true
    end

    test "returns false when count >= max" do
      {:ok, policy} = EnrollmentPolicy.new(%{program_id: "p", max_enrollment: 10})
      assert EnrollmentPolicy.has_capacity?(policy, 10) == false
    end

    test "returns true when no max set (min only)" do
      {:ok, policy} = EnrollmentPolicy.new(%{program_id: "p", min_enrollment: 5})
      assert EnrollmentPolicy.has_capacity?(policy, 999) == true
    end
  end

  describe "meets_minimum?/2" do
    test "returns true when count >= min" do
      {:ok, policy} = EnrollmentPolicy.new(%{program_id: "p", min_enrollment: 5})
      assert EnrollmentPolicy.meets_minimum?(policy, 5) == true
    end

    test "returns false when count < min" do
      {:ok, policy} = EnrollmentPolicy.new(%{program_id: "p", min_enrollment: 5})
      assert EnrollmentPolicy.meets_minimum?(policy, 3) == false
    end

    test "returns true when no min set" do
      {:ok, policy} = EnrollmentPolicy.new(%{program_id: "p", max_enrollment: 20})
      assert EnrollmentPolicy.meets_minimum?(policy, 0) == true
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/enrollment/domain/models/enrollment_policy_test.exs`
Expected: Compilation error — module `EnrollmentPolicy` does not exist

**Step 3: Write minimal implementation**

```elixir
# lib/klass_hero/enrollment/domain/models/enrollment_policy.ex
defmodule KlassHero.Enrollment.Domain.Models.EnrollmentPolicy do
  @moduledoc """
  Domain model representing enrollment capacity constraints for a program.

  Owned by the Enrollment context. Providers configure min/max enrollment
  when creating programs; the enrollment context enforces these limits.
  """

  @enforce_keys [:program_id]

  defstruct [
    :id,
    :program_id,
    :min_enrollment,
    :max_enrollment,
    :inserted_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          program_id: String.t(),
          min_enrollment: pos_integer() | nil,
          max_enrollment: pos_integer() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @spec new(map()) :: {:ok, t()} | {:error, [String.t()]}
  def new(attrs) when is_map(attrs) do
    errors =
      []
      |> validate_program_id(attrs[:program_id])
      |> validate_min(attrs[:min_enrollment])
      |> validate_max(attrs[:max_enrollment])
      |> validate_min_max_relationship(attrs[:min_enrollment], attrs[:max_enrollment])
      |> validate_at_least_one(attrs[:min_enrollment], attrs[:max_enrollment])

    if errors == [] do
      {:ok,
       %__MODULE__{
         id: attrs[:id],
         program_id: attrs[:program_id],
         min_enrollment: attrs[:min_enrollment],
         max_enrollment: attrs[:max_enrollment],
         inserted_at: attrs[:inserted_at],
         updated_at: attrs[:updated_at]
       }}
    else
      {:error, errors}
    end
  end

  @doc """
  Returns true if the current enrollment count is below the maximum capacity.
  Always true when no max_enrollment is set.
  """
  @spec has_capacity?(t(), non_neg_integer()) :: boolean()
  def has_capacity?(%__MODULE__{max_enrollment: nil}, _count), do: true
  def has_capacity?(%__MODULE__{max_enrollment: max}, count), do: count < max

  @doc """
  Returns true if the current enrollment count meets the minimum threshold.
  Always true when no min_enrollment is set.
  """
  @spec meets_minimum?(t(), non_neg_integer()) :: boolean()
  def meets_minimum?(%__MODULE__{min_enrollment: nil}, _count), do: true
  def meets_minimum?(%__MODULE__{min_enrollment: min}, count), do: count >= min

  defp validate_program_id(errors, id) when is_binary(id) and byte_size(id) > 0, do: errors
  defp validate_program_id(errors, _), do: ["program ID is required" | errors]

  defp validate_min(errors, nil), do: errors
  defp validate_min(errors, min) when is_integer(min) and min >= 1, do: errors
  defp validate_min(errors, _), do: ["minimum enrollment must be at least 1" | errors]

  defp validate_max(errors, nil), do: errors
  defp validate_max(errors, max) when is_integer(max) and max >= 1, do: errors
  defp validate_max(errors, _), do: ["maximum enrollment must be at least 1" | errors]

  defp validate_min_max_relationship(errors, min, max)
       when is_integer(min) and is_integer(max) and min > max do
    ["minimum enrollment must not exceed maximum enrollment" | errors]
  end

  defp validate_min_max_relationship(errors, _min, _max), do: errors

  defp validate_at_least_one(errors, nil, nil) do
    ["at least one of minimum or maximum enrollment is required" | errors]
  end

  defp validate_at_least_one(errors, _min, _max), do: errors
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/enrollment/domain/models/enrollment_policy_test.exs`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/klass_hero/enrollment/domain/models/enrollment_policy.ex test/klass_hero/enrollment/domain/models/enrollment_policy_test.exs
git commit -m "feat: add EnrollmentPolicy domain model (#149)"
```

---

## Task 2: EnrollmentPolicy Port

**Files:**
- Create: `lib/klass_hero/enrollment/domain/ports/for_managing_enrollment_policies.ex`

**Step 1: Write the port behaviour**

```elixir
# lib/klass_hero/enrollment/domain/ports/for_managing_enrollment_policies.ex
defmodule KlassHero.Enrollment.Domain.Ports.ForManagingEnrollmentPolicies do
  @moduledoc """
  Port defining the contract for enrollment policy persistence.

  Implementations handle storing and retrieving enrollment capacity
  configuration (min/max enrollment) for programs.
  """

  alias KlassHero.Enrollment.Domain.Models.EnrollmentPolicy

  @doc """
  Creates or updates an enrollment policy for a program.
  Uses upsert semantics — if a policy already exists for the program_id, it is updated.
  """
  @callback upsert(attrs :: map()) ::
              {:ok, EnrollmentPolicy.t()} | {:error, term()}

  @doc """
  Retrieves the enrollment policy for a program.
  """
  @callback get_by_program_id(program_id :: binary()) ::
              {:ok, EnrollmentPolicy.t()} | {:error, :not_found}

  @doc """
  Returns the remaining enrollment capacity for a program.

  Calculates: max_enrollment - count(active enrollments).
  Returns :unlimited when no max_enrollment is configured.
  """
  @callback get_remaining_capacity(program_id :: binary()) ::
              {:ok, non_neg_integer() | :unlimited}

  @doc """
  Returns the count of active enrollments for a program.
  Active means status is 'pending' or 'confirmed'.
  """
  @callback count_active_enrollments(program_id :: binary()) :: non_neg_integer()
end
```

**Step 2: No test needed — this is a behaviour definition. Commit.**

```bash
git add lib/klass_hero/enrollment/domain/ports/for_managing_enrollment_policies.ex
git commit -m "feat: add ForManagingEnrollmentPolicies port (#149)"
```

---

## Task 3: EnrollmentPolicy Persistence (Schema, Mapper, Repository, Migration)

**Files:**
- Create: `lib/klass_hero/enrollment/adapters/driven/persistence/schemas/enrollment_policy_schema.ex`
- Create: `lib/klass_hero/enrollment/adapters/driven/persistence/mappers/enrollment_policy_mapper.ex`
- Create: `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_policy_repository.ex`
- Create: migration via `mix ecto.gen.migration create_enrollment_policies`
- Test: `test/klass_hero/enrollment/adapters/driven/persistence/schemas/enrollment_policy_schema_test.exs`
- Test: `test/klass_hero/enrollment/adapters/driven/persistence/mappers/enrollment_policy_mapper_test.exs`
- Test: `test/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_policy_repository_test.exs`

### Step 1: Create migration

Run: `mix ecto.gen.migration create_enrollment_policies`

Then edit the generated migration:

```elixir
defmodule KlassHero.Repo.Migrations.CreateEnrollmentPolicies do
  use Ecto.Migration

  def change do
    create table(:enrollment_policies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :program_id, references(:programs, type: :binary_id, on_delete: :delete_all), null: false
      add :min_enrollment, :integer
      add :max_enrollment, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:enrollment_policies, [:program_id])

    # Trigger: ensure database-level integrity for capacity values
    # Why: defense-in-depth — domain validates first, DB catches anything that slips through
    # Outcome: invalid values rejected at DB level even if domain validation bypassed
    create constraint(:enrollment_policies, :min_enrollment_positive,
             check: "min_enrollment IS NULL OR min_enrollment >= 1")

    create constraint(:enrollment_policies, :max_enrollment_positive,
             check: "max_enrollment IS NULL OR max_enrollment >= 1")

    create constraint(:enrollment_policies, :min_not_exceeds_max,
             check: "min_enrollment IS NULL OR max_enrollment IS NULL OR min_enrollment <= max_enrollment")
  end
end
```

### Step 2: Write Ecto schema

```elixir
# lib/klass_hero/enrollment/adapters/driven/persistence/schemas/enrollment_policy_schema.ex
defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentPolicySchema do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "enrollment_policies" do
    field :program_id, :binary_id
    field :min_enrollment, :integer
    field :max_enrollment, :integer

    timestamps()
  end

  @required_fields ~w(program_id)a
  @optional_fields ~w(min_enrollment max_enrollment)a

  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:min_enrollment, greater_than_or_equal_to: 1)
    |> validate_number(:max_enrollment, greater_than_or_equal_to: 1)
    |> validate_min_not_exceeds_max()
    |> unique_constraint(:program_id)
    |> check_constraint(:min_enrollment, name: :min_enrollment_positive)
    |> check_constraint(:max_enrollment, name: :max_enrollment_positive)
    |> check_constraint(:min_enrollment, name: :min_not_exceeds_max)
  end

  defp validate_min_not_exceeds_max(changeset) do
    min = get_field(changeset, :min_enrollment)
    max = get_field(changeset, :max_enrollment)

    if is_integer(min) and is_integer(max) and min > max do
      add_error(changeset, :min_enrollment, "must not exceed maximum enrollment")
    else
      changeset
    end
  end
end
```

### Step 3: Write mapper

```elixir
# lib/klass_hero/enrollment/adapters/driven/persistence/mappers/enrollment_policy_mapper.ex
defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.EnrollmentPolicyMapper do
  @moduledoc """
  Maps between EnrollmentPolicy domain model and Ecto schema.
  """

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentPolicySchema
  alias KlassHero.Enrollment.Domain.Models.EnrollmentPolicy

  @spec to_domain(EnrollmentPolicySchema.t()) :: EnrollmentPolicy.t()
  def to_domain(%EnrollmentPolicySchema{} = schema) do
    %EnrollmentPolicy{
      id: to_string(schema.id),
      program_id: to_string(schema.program_id),
      min_enrollment: schema.min_enrollment,
      max_enrollment: schema.max_enrollment,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @spec to_schema_attrs(map()) :: map()
  def to_schema_attrs(attrs) when is_map(attrs) do
    %{
      program_id: attrs[:program_id],
      min_enrollment: attrs[:min_enrollment],
      max_enrollment: attrs[:max_enrollment]
    }
  end
end
```

### Step 4: Write repository

```elixir
# lib/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_policy_repository.ex
defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.EnrollmentPolicyRepository do
  @moduledoc """
  Ecto-based implementation of the ForManagingEnrollmentPolicies port.
  """

  @behaviour KlassHero.Enrollment.Domain.Ports.ForManagingEnrollmentPolicies

  import Ecto.Query

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.EnrollmentPolicyMapper
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentPolicySchema
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentSchema
  alias KlassHero.Repo

  require Logger

  @active_statuses ~w(pending confirmed)

  @impl true
  def upsert(attrs) do
    schema_attrs = EnrollmentPolicyMapper.to_schema_attrs(attrs)

    %EnrollmentPolicySchema{}
    |> EnrollmentPolicySchema.changeset(schema_attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:min_enrollment, :max_enrollment, :updated_at]},
      conflict_target: :program_id,
      returning: true
    )
    |> case do
      {:ok, schema} ->
        Logger.info("[Enrollment.PolicyRepository] Upserted enrollment policy",
          program_id: schema.program_id,
          min: schema.min_enrollment,
          max: schema.max_enrollment
        )

        {:ok, EnrollmentPolicyMapper.to_domain(schema)}

      {:error, changeset} ->
        Logger.warning("[Enrollment.PolicyRepository] Failed to upsert policy",
          errors: inspect(changeset.errors)
        )

        {:error, changeset}
    end
  end

  @impl true
  def get_by_program_id(program_id) do
    case Repo.get_by(EnrollmentPolicySchema, program_id: program_id) do
      nil -> {:error, :not_found}
      schema -> {:ok, EnrollmentPolicyMapper.to_domain(schema)}
    end
  end

  @impl true
  def get_remaining_capacity(program_id) do
    case Repo.get_by(EnrollmentPolicySchema, program_id: program_id) do
      nil ->
        {:ok, :unlimited}

      %{max_enrollment: nil} ->
        {:ok, :unlimited}

      %{max_enrollment: max} ->
        active_count = count_active_enrollments(program_id)
        {:ok, max(max - active_count, 0)}
    end
  end

  @impl true
  def count_active_enrollments(program_id) do
    from(e in EnrollmentSchema,
      where: e.program_id == ^program_id and e.status in ^@active_statuses,
      select: count(e.id)
    )
    |> Repo.one()
  end
end
```

### Step 5: Write schema test

```elixir
# test/klass_hero/enrollment/adapters/driven/persistence/schemas/enrollment_policy_schema_test.exs
defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentPolicySchemaTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentPolicySchema

  describe "changeset/2" do
    test "valid with program_id and max_enrollment" do
      changeset = EnrollmentPolicySchema.changeset(%{
        program_id: Ecto.UUID.generate(),
        max_enrollment: 20
      })
      assert changeset.valid?
    end

    test "valid with program_id and min_enrollment" do
      changeset = EnrollmentPolicySchema.changeset(%{
        program_id: Ecto.UUID.generate(),
        min_enrollment: 5
      })
      assert changeset.valid?
    end

    test "invalid without program_id" do
      changeset = EnrollmentPolicySchema.changeset(%{max_enrollment: 20})
      refute changeset.valid?
      assert %{program_id: _} = errors_on(changeset)
    end

    test "invalid when min < 1" do
      changeset = EnrollmentPolicySchema.changeset(%{
        program_id: Ecto.UUID.generate(),
        min_enrollment: 0
      })
      refute changeset.valid?
    end

    test "invalid when max < 1" do
      changeset = EnrollmentPolicySchema.changeset(%{
        program_id: Ecto.UUID.generate(),
        max_enrollment: 0
      })
      refute changeset.valid?
    end

    test "invalid when min > max" do
      changeset = EnrollmentPolicySchema.changeset(%{
        program_id: Ecto.UUID.generate(),
        min_enrollment: 25,
        max_enrollment: 10
      })
      refute changeset.valid?
    end
  end
end
```

### Step 6: Write mapper test

```elixir
# test/klass_hero/enrollment/adapters/driven/persistence/mappers/enrollment_policy_mapper_test.exs
defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.EnrollmentPolicyMapperTest do
  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Mappers.EnrollmentPolicyMapper
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentPolicySchema
  alias KlassHero.Enrollment.Domain.Models.EnrollmentPolicy

  describe "to_domain/1" do
    test "maps schema to domain model" do
      id = Ecto.UUID.generate()
      program_id = Ecto.UUID.generate()
      now = DateTime.utc_now()

      schema = %EnrollmentPolicySchema{
        id: id,
        program_id: program_id,
        min_enrollment: 5,
        max_enrollment: 20,
        inserted_at: now,
        updated_at: now
      }

      result = EnrollmentPolicyMapper.to_domain(schema)

      assert %EnrollmentPolicy{} = result
      assert result.id == to_string(id)
      assert result.program_id == to_string(program_id)
      assert result.min_enrollment == 5
      assert result.max_enrollment == 20
    end
  end

  describe "to_schema_attrs/1" do
    test "maps attrs to schema-compatible map" do
      attrs = %{program_id: "prog-1", min_enrollment: 5, max_enrollment: 20}
      result = EnrollmentPolicyMapper.to_schema_attrs(attrs)

      assert result.program_id == "prog-1"
      assert result.min_enrollment == 5
      assert result.max_enrollment == 20
    end
  end
end
```

### Step 7: Write repository test

```elixir
# test/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_policy_repository_test.exs
defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.EnrollmentPolicyRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.EnrollmentPolicyRepository

  describe "upsert/1" do
    test "creates a new policy" do
      program = insert(:program_schema)

      assert {:ok, policy} =
               EnrollmentPolicyRepository.upsert(%{
                 program_id: program.id,
                 min_enrollment: 5,
                 max_enrollment: 20
               })

      assert policy.program_id == to_string(program.id)
      assert policy.min_enrollment == 5
      assert policy.max_enrollment == 20
    end

    test "updates existing policy on conflict" do
      program = insert(:program_schema)

      {:ok, _} =
        EnrollmentPolicyRepository.upsert(%{
          program_id: program.id,
          max_enrollment: 20
        })

      {:ok, updated} =
        EnrollmentPolicyRepository.upsert(%{
          program_id: program.id,
          max_enrollment: 30,
          min_enrollment: 10
        })

      assert updated.max_enrollment == 30
      assert updated.min_enrollment == 10
    end
  end

  describe "get_by_program_id/1" do
    test "returns policy when it exists" do
      program = insert(:program_schema)
      {:ok, _} = EnrollmentPolicyRepository.upsert(%{program_id: program.id, max_enrollment: 20})

      assert {:ok, policy} = EnrollmentPolicyRepository.get_by_program_id(program.id)
      assert policy.max_enrollment == 20
    end

    test "returns :not_found when no policy exists" do
      assert {:error, :not_found} =
               EnrollmentPolicyRepository.get_by_program_id(Ecto.UUID.generate())
    end
  end

  describe "get_remaining_capacity/1" do
    test "returns :unlimited when no policy exists" do
      assert {:ok, :unlimited} =
               EnrollmentPolicyRepository.get_remaining_capacity(Ecto.UUID.generate())
    end

    test "returns :unlimited when max is nil" do
      program = insert(:program_schema)
      {:ok, _} = EnrollmentPolicyRepository.upsert(%{program_id: program.id, min_enrollment: 5})

      assert {:ok, :unlimited} =
               EnrollmentPolicyRepository.get_remaining_capacity(program.id)
    end

    test "returns remaining spots" do
      program = insert(:program_schema)
      child = insert(:child_schema)

      {:ok, _} = EnrollmentPolicyRepository.upsert(%{program_id: program.id, max_enrollment: 10})

      # Create 3 active enrollments
      insert(:enrollment_schema, program_id: program.id, child_id: child.id, status: "pending")

      child2 = insert(:child_schema)
      insert(:enrollment_schema, program_id: program.id, child_id: child2.id, status: "confirmed")

      child3 = insert(:child_schema)
      insert(:enrollment_schema, program_id: program.id, child_id: child3.id, status: "confirmed")

      assert {:ok, 7} = EnrollmentPolicyRepository.get_remaining_capacity(program.id)
    end

    test "does not count cancelled enrollments" do
      program = insert(:program_schema)
      child = insert(:child_schema)

      {:ok, _} = EnrollmentPolicyRepository.upsert(%{program_id: program.id, max_enrollment: 10})
      insert(:enrollment_schema, program_id: program.id, child_id: child.id, status: "cancelled")

      assert {:ok, 10} = EnrollmentPolicyRepository.get_remaining_capacity(program.id)
    end

    test "returns 0 when at capacity (never negative)" do
      program = insert(:program_schema)
      {:ok, _} = EnrollmentPolicyRepository.upsert(%{program_id: program.id, max_enrollment: 1})

      child = insert(:child_schema)
      insert(:enrollment_schema, program_id: program.id, child_id: child.id, status: "pending")

      child2 = insert(:child_schema)
      insert(:enrollment_schema, program_id: program.id, child_id: child2.id, status: "confirmed")

      assert {:ok, 0} = EnrollmentPolicyRepository.get_remaining_capacity(program.id)
    end
  end

  describe "count_active_enrollments/1" do
    test "counts pending and confirmed enrollments" do
      program = insert(:program_schema)
      child1 = insert(:child_schema)
      child2 = insert(:child_schema)
      child3 = insert(:child_schema)

      insert(:enrollment_schema, program_id: program.id, child_id: child1.id, status: "pending")
      insert(:enrollment_schema, program_id: program.id, child_id: child2.id, status: "confirmed")
      insert(:enrollment_schema, program_id: program.id, child_id: child3.id, status: "cancelled")

      assert EnrollmentPolicyRepository.count_active_enrollments(program.id) == 2
    end
  end
end
```

### Step 8: Run migration and all tests

Run: `mix ecto.migrate && mix test test/klass_hero/enrollment/adapters/driven/persistence/`
Expected: All pass

### Step 9: Commit

```bash
git add lib/klass_hero/enrollment/adapters/driven/persistence/ priv/repo/migrations/*create_enrollment_policies* test/klass_hero/enrollment/adapters/driven/persistence/
git commit -m "feat: add EnrollmentPolicy persistence layer (#149)"
```

---

## Task 4: Register EnrollmentPolicy Repository in Config + Context Facade

**Files:**
- Modify: `config/config.exs:68-70` — add enrollment policy repo config
- Modify: `lib/klass_hero/enrollment.ex` — add public facade functions

### Step 1: Add config

In `config/config.exs`, the enrollment config block (line 68-70) currently has:
```elixir
config :klass_hero, :enrollment,
  for_managing_enrollments: KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.EnrollmentRepository
```

Add the new policy repository:
```elixir
config :klass_hero, :enrollment,
  for_managing_enrollments:
    KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.EnrollmentRepository,
  for_managing_enrollment_policies:
    KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.EnrollmentPolicyRepository
```

### Step 2: Add facade functions to `lib/klass_hero/enrollment.ex`

Add to the enrollment context facade (after the existing cross-context query functions section, before `end`):

```elixir
# ============================================================================
# Enrollment Policy Functions
# ============================================================================

@doc """
Creates or updates enrollment capacity policy for a program.

## Parameters
- attrs: Map with :program_id (required), :min_enrollment, :max_enrollment (at least one required)

## Returns
- `{:ok, EnrollmentPolicy.t()}` on success
- `{:error, term()}` on validation failure
"""
def set_enrollment_policy(attrs) when is_map(attrs) do
  policy_repo().upsert(attrs)
end

@doc """
Returns the enrollment policy for a program.
"""
def get_enrollment_policy(program_id) when is_binary(program_id) do
  policy_repo().get_by_program_id(program_id)
end

@doc """
Returns remaining enrollment capacity for a program.

- `{:ok, non_neg_integer()}` — remaining spots
- `{:ok, :unlimited}` — no maximum configured
"""
def remaining_capacity(program_id) when is_binary(program_id) do
  policy_repo().get_remaining_capacity(program_id)
end

@doc """
Returns the count of active (pending/confirmed) enrollments for a program.
"""
def count_active_enrollments(program_id) when is_binary(program_id) do
  policy_repo().count_active_enrollments(program_id)
end

defp policy_repo do
  Application.get_env(:klass_hero, :enrollment)[:for_managing_enrollment_policies]
end
```

Also add the alias at the top of the module (with the other aliases):
```elixir
alias KlassHero.Enrollment.Domain.Models.EnrollmentPolicy
```

### Step 3: Run tests

Run: `mix test test/klass_hero/enrollment/`
Expected: All pass

### Step 4: Commit

```bash
git add config/config.exs lib/klass_hero/enrollment.ex
git commit -m "feat: wire EnrollmentPolicy into config and context facade (#149)"
```

---

## Task 5: Add Capacity Check to CreateEnrollment Use Case

**Files:**
- Modify: `lib/klass_hero/enrollment/application/use_cases/create_enrollment.ex`
- Test: `test/klass_hero/enrollment/application/use_cases/create_enrollment_test.exs` — add capacity tests

### Step 1: Write the failing test

Add to the existing `create_enrollment_test.exs`:

```elixir
describe "capacity enforcement" do
  test "rejects enrollment when program is at max capacity" do
    program = insert(:program_schema)
    child1 = insert(:child_schema)
    child2 = insert(:child_schema)

    # Set max capacity to 1
    Enrollment.set_enrollment_policy(%{program_id: program.id, max_enrollment: 1})

    # First enrollment succeeds
    {:ok, _} = CreateEnrollment.execute(%{
      program_id: program.id,
      child_id: child1.id,
      parent_id: child1.parent_id
    })

    # Second enrollment rejected
    assert {:error, :program_full} = CreateEnrollment.execute(%{
      program_id: program.id,
      child_id: child2.id,
      parent_id: child2.parent_id
    })
  end

  test "allows enrollment when no policy exists (unlimited)" do
    program = insert(:program_schema)
    child = insert(:child_schema)

    assert {:ok, _} = CreateEnrollment.execute(%{
      program_id: program.id,
      child_id: child.id,
      parent_id: child.parent_id
    })
  end

  test "allows enrollment when under max capacity" do
    program = insert(:program_schema)
    child = insert(:child_schema)

    Enrollment.set_enrollment_policy(%{program_id: program.id, max_enrollment: 10})

    assert {:ok, _} = CreateEnrollment.execute(%{
      program_id: program.id,
      child_id: child.id,
      parent_id: child.parent_id
    })
  end
end
```

### Step 2: Run test to verify it fails

Run: `mix test test/klass_hero/enrollment/application/use_cases/create_enrollment_test.exs`
Expected: First test in "capacity enforcement" fails — no `:program_full` error returned

### Step 3: Add capacity check to CreateEnrollment

In `create_enrollment.ex`, add a capacity validation step. Modify both `create_enrollment_with_validation/2` and `create_enrollment_direct/1`:

**In `create_enrollment_with_validation/2` (line 59-71)**, add capacity check to the `with` chain:

```elixir
defp create_enrollment_with_validation(identity_id, params) do
  with {:ok, parent} <- validate_parent_profile(identity_id),
       :ok <- validate_booking_entitlement(parent),
       :ok <- validate_program_capacity(params[:program_id]) do
    attrs = build_enrollment_attrs(params, parent.id)

    Logger.info("[Enrollment.CreateEnrollment] Creating enrollment with validation",
      program_id: attrs[:program_id],
      child_id: attrs[:child_id],
      parent_id: attrs[:parent_id]
    )

    repository().create(attrs)
  end
end
```

**In `create_enrollment_direct/1` (line 74-84)**, add capacity check:

```elixir
defp create_enrollment_direct(params) do
  with :ok <- validate_program_capacity(params[:program_id]) do
    attrs = build_enrollment_attrs(params, params[:parent_id])

    Logger.info("[Enrollment.CreateEnrollment] Creating enrollment (direct)",
      program_id: attrs[:program_id],
      child_id: attrs[:child_id],
      parent_id: attrs[:parent_id]
    )

    repository().create(attrs)
  end
end
```

**Add the new private function:**

```elixir
defp validate_program_capacity(program_id) do
  case policy_repo().get_remaining_capacity(program_id) do
    {:ok, :unlimited} ->
      :ok

    {:ok, remaining} when remaining > 0 ->
      :ok

    {:ok, 0} ->
      Logger.info("[Enrollment.CreateEnrollment] Program full",
        program_id: program_id
      )

      {:error, :program_full}
  end
end

defp policy_repo do
  Application.get_env(:klass_hero, :enrollment)[:for_managing_enrollment_policies]
end
```

### Step 4: Run test to verify it passes

Run: `mix test test/klass_hero/enrollment/application/use_cases/create_enrollment_test.exs`
Expected: All pass

### Step 5: Commit

```bash
git add lib/klass_hero/enrollment/application/use_cases/create_enrollment.ex test/klass_hero/enrollment/application/use_cases/create_enrollment_test.exs
git commit -m "feat: enforce max capacity in CreateEnrollment use case (#149)"
```

---

## Task 6: Remove spots_available from Program Catalog

**Files:**
- Modify: `lib/klass_hero/program_catalog/domain/models/program.ex` — remove field, `sold_out?/1`, validations
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema.ex` — remove field
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper.ex` — remove mapping
- Create: migration to remove column and migrate data
- Update: affected tests across program_catalog

This is a wide-reaching change. The implementer should:

### Step 1: Create data migration

Run: `mix ecto.gen.migration migrate_spots_available_to_enrollment_policies`

```elixir
defmodule KlassHero.Repo.Migrations.MigrateSpotsAvailableToEnrollmentPolicies do
  use Ecto.Migration

  def up do
    # Trigger: programs with spots_available > 0 need their capacity migrated
    # Why: enrollment context now owns capacity; this preserves existing data
    # Outcome: enrollment_policies rows created, spots_available column dropped
    execute """
    INSERT INTO enrollment_policies (id, program_id, max_enrollment, inserted_at, updated_at)
    SELECT gen_random_uuid(), id, spots_available, NOW(), NOW()
    FROM programs
    WHERE spots_available > 0
    ON CONFLICT (program_id) DO NOTHING
    """

    alter table(:programs) do
      remove :spots_available
    end
  end

  def down do
    alter table(:programs) do
      add :spots_available, :integer, default: 0, null: false
    end

    execute """
    UPDATE programs p
    SET spots_available = COALESCE(
      (SELECT max_enrollment FROM enrollment_policies ep WHERE ep.program_id = p.id),
      0
    )
    """
  end
end
```

### Step 2: Remove from Program domain model

In `lib/klass_hero/program_catalog/domain/models/program.ex`:

- **Line 36**: Remove `spots_available: 0` from defstruct
- **Line 49**: Remove `spots_available: non_neg_integer()` from @type
- **Lines 135-136**: Remove `sold_out?/1` function entirely
- **Line 207**: Remove `spots_available: attrs[:spots_available] || 0,` from `build_base/3`
- **Line 226**: Remove `|> validate_spots(attrs[:spots_available])` from `validate_creation_invariants/1`
- **Lines 261-265**: Remove all `validate_spots/2` clauses
- **Line 285**: Remove `spots_available` from `@updatable_fields`
- **Line 311**: Remove `|> validate_spots(program.spots_available)` from `validate_mutation_invariants/1`

### Step 3: Remove from ProgramSchema

In `lib/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema.ex`:

- **Line 29**: Remove `field :spots_available, :integer, default: 0`
- **Line 57**: Remove from type spec
- **Line 100**: Remove `:spots_available` from cast list in `changeset/2`
- **Line 123**: Remove from required list in `changeset/2`
- **Line 131**: Remove `validate_number(:spots_available, ...)` from `changeset/2`
- **Line 152**: Remove from cast list in `create_changeset/2`
- **Line 177**: Remove `validate_number(:spots_available, ...)` from `create_changeset/2`
- **Line 204**: Remove from cast list in `update_changeset/2`
- **Line 224**: Remove from required list in `update_changeset/2`
- **Line 232**: Remove `validate_number(:spots_available, ...)` from `update_changeset/2`

### Step 4: Remove from ProgramMapper

In `lib/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper.ex`:

- **Line 59**: Remove `spots_available: schema.spots_available || 0,`
- **Line 129**: Remove `spots_available: program.spots_available,`

### Step 5: Update Factory

In `test/support/factory.ex`:
- Remove `spots_available: 10` (or similar) from `program_factory/0` and `program_schema_factory/0`

### Step 6: Fix all broken tests

Search for `spots_available` and `sold_out?` across all test files and remove/update references. Key files:
- `test/klass_hero/program_catalog/domain/models/program_test.exs`
- `test/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema_test.exs`
- `test/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper_test.exs`
- `test/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_repository_test.exs`
- `test/klass_hero/program_catalog/create_program_integration_test.exs`
- `test/klass_hero/program_catalog/update_program_integration_test.exs`

### Step 7: Run full test suite

Run: `mix test`
Expected: All pass (some tests may need updating for removed field)

### Step 8: Commit

```bash
git add -A
git commit -m "refactor: remove spots_available from Program, migrate to enrollment policies (#149)"
```

---

## Task 7: ACL for Program Catalog to Read Enrollment Capacity

**Files:**
- Create: `lib/klass_hero/program_catalog/domain/services/enrollment_capacity_acl.ex`
- Modify: `lib/klass_hero/program_catalog.ex` — add Boundary dep on Enrollment, add facade function
- Modify: `lib/klass_hero_web/live/programs_live.ex:118` — use ACL instead of `spots_available`
- Test: `test/klass_hero/program_catalog/domain/services/enrollment_capacity_acl_test.exs`

### Step 1: Write ACL module

```elixir
# lib/klass_hero/program_catalog/domain/services/enrollment_capacity_acl.ex
defmodule KlassHero.ProgramCatalog.Domain.Services.EnrollmentCapacityACL do
  @moduledoc """
  Anti-corruption layer for reading enrollment capacity from the Enrollment context.

  The Program Catalog context doesn't own capacity data — it queries the
  Enrollment context through this ACL to display remaining spots.
  """

  alias KlassHero.Enrollment

  @doc """
  Returns remaining capacity for a program.

  - `{:ok, non_neg_integer()}` — remaining spots
  - `{:ok, :unlimited}` — no maximum configured
  """
  @spec remaining_capacity(String.t()) :: {:ok, non_neg_integer() | :unlimited}
  def remaining_capacity(program_id) do
    Enrollment.remaining_capacity(program_id)
  end
end
```

### Step 2: Add Boundary dep

In `lib/klass_hero/program_catalog.ex` line 37-38, add `KlassHero.Enrollment` to deps:

```elixir
use Boundary,
  top_level?: true,
  deps: [KlassHero, KlassHero.Provider, KlassHero.Shared, KlassHero.Enrollment],
  exports: [
```

### Step 3: Add facade function

In `lib/klass_hero/program_catalog.ex`, add:

```elixir
@doc """
Returns remaining enrollment capacity for a program via ACL.
Delegates to the Enrollment context.
"""
defdelegate remaining_capacity(program_id),
  to: KlassHero.ProgramCatalog.Domain.Services.EnrollmentCapacityACL
```

### Step 4: Update ProgramsLive

In `lib/klass_hero_web/live/programs_live.ex:118`, replace:
```elixir
spots_left: program.spots_available,
```
with:
```elixir
spots_left: get_remaining_capacity(program.id),
```

Add private helper:
```elixir
defp get_remaining_capacity(program_id) do
  case ProgramCatalog.remaining_capacity(program_id) do
    {:ok, :unlimited} -> nil
    {:ok, count} -> count
  end
end
```

### Step 5: Run tests

Run: `mix test`
Expected: All pass

### Step 6: Commit

```bash
git add lib/klass_hero/program_catalog/ lib/klass_hero_web/live/programs_live.ex
git commit -m "feat: add EnrollmentCapacityACL for program catalog capacity display (#149)"
```

---

## Task 8: Update BookingLive to Use Enrollment Capacity

**Files:**
- Modify: `lib/klass_hero_web/live/booking_live.ex` — replace `validate_program_availability/1`
- Update: `test/klass_hero_web/live/booking_live_test.exs`

### Step 1: Replace validate_program_availability

In `booking_live.ex`, replace lines 219-222:

```elixir
defp validate_program_availability(%{spots_available: spots_available})
     when spots_available > 0, do: :ok

defp validate_program_availability(_program), do: {:error, :no_spots}
```

with:

```elixir
defp validate_program_availability(program) do
  case Enrollment.remaining_capacity(program.id) do
    {:ok, :unlimited} -> :ok
    {:ok, remaining} when remaining > 0 -> :ok
    {:ok, 0} -> {:error, :no_spots}
  end
end
```

Also add `:program_full` error handling in `complete_enrollment` (alongside existing `:no_spots`):

In the `handle_event("complete_enrollment", ...)` error handler, add after the `:no_spots` clause:

```elixir
{:error, :program_full} ->
  {:noreply,
   socket
   |> put_flash(
     :error,
     gettext("Sorry, this program is now full. Please choose another program.")
   )
   |> push_navigate(to: ~p"/programs")}
```

### Step 2: Update tests

Update any booking_live tests that relied on `spots_available` field. Tests that create programs with `spots_available: 10` should instead create an enrollment policy:

```elixir
# After creating the program, set capacity:
Enrollment.set_enrollment_policy(%{program_id: program.id, max_enrollment: 10})
```

### Step 3: Run tests

Run: `mix test test/klass_hero_web/live/booking_live_test.exs`
Expected: All pass

### Step 4: Commit

```bash
git add lib/klass_hero_web/live/booking_live.ex test/klass_hero_web/live/booking_live_test.exs
git commit -m "feat: BookingLive uses enrollment capacity instead of spots_available (#149)"
```

---

## Task 9: Provider Form — Add Capacity Fields

**Files:**
- Modify: `lib/klass_hero_web/components/provider_components.ex:863` — add capacity fields
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex:474` — save policy after program creation

### Step 1: Add capacity fields to provider form

In `provider_components.ex`, after the Registration Period section (line 863) and before the Description textarea (line 865), insert:

```heex
<%!-- Enrollment Capacity Section --%>
<div class="space-y-3">
  <p class="text-sm font-semibold text-hero-charcoal">
    {gettext("Enrollment Capacity (optional)")}
  </p>
  <p class="text-xs text-hero-grey-500">
    {gettext("Set minimum and maximum enrollment for this program.")}
  </p>
  <div class="grid grid-cols-2 gap-4">
    <.input
      field={@form[:min_enrollment]}
      type="number"
      label={gettext("Minimum Enrollment")}
      min="1"
    />
    <.input
      field={@form[:max_enrollment]}
      type="number"
      label={gettext("Maximum Enrollment")}
      min="1"
    />
  </div>
</div>
```

### Step 2: Add enrollment policy fields to ProgramSchema

The form fields need to exist on the Ecto schema changeset even though they won't be persisted to the programs table. Add virtual fields to the program schema for form support, **OR** handle the fields directly in the LiveView params without putting them on the schema.

**Recommended: handle in LiveView params directly** — extract min/max from params before building program attrs, then pass to enrollment context separately.

### Step 3: Update save_program handler

In `dashboard_live.ex`, after line 475 (`{:ok, program} <- ProgramCatalog.create_program(attrs)`), add enrollment policy creation:

```elixir
with {:ok, attrs} <- maybe_add_instructor(attrs, params["instructor_id"], socket),
     {:ok, program} <- ProgramCatalog.create_program(attrs),
     :ok <- maybe_set_enrollment_policy(program.id, params) do
```

Add the helper:

```elixir
defp maybe_set_enrollment_policy(program_id, params) do
  min = parse_integer(params["min_enrollment"])
  max = parse_integer(params["max_enrollment"])

  # Trigger: both capacity fields are blank
  # Why: no policy needed when provider doesn't set capacity constraints
  # Outcome: skip policy creation, return :ok
  if is_nil(min) and is_nil(max) do
    :ok
  else
    case Enrollment.set_enrollment_policy(%{
           program_id: program_id,
           min_enrollment: min,
           max_enrollment: max
         }) do
      {:ok, _policy} -> :ok
      {:error, _} -> :ok  # Program created successfully, log capacity warning
    end
  end
end

defp parse_integer(nil), do: nil
defp parse_integer(""), do: nil
defp parse_integer(val) when is_binary(val) do
  case Integer.parse(val) do
    {int, _} when int >= 1 -> int
    _ -> nil
  end
end
defp parse_integer(val) when is_integer(val), do: val
```

Add the alias at the top of the module:
```elixir
alias KlassHero.Enrollment
```

### Step 4: Add min/max fields to the ProgramSchema changeset for form display

Since the program form uses `to_form(ProgramSchema.changeset(...))`, we need virtual fields on the schema for the form to work. Add to `program_schema.ex`:

```elixir
field :min_enrollment, :integer, virtual: true
field :max_enrollment, :integer, virtual: true
```

And add `:min_enrollment, :max_enrollment` to the cast list in `changeset/2` only (the general form changeset), NOT to `create_changeset` or `update_changeset` since these don't persist.

### Step 5: Run tests

Run: `mix test test/klass_hero_web/live/provider/`
Expected: All pass

### Step 6: Commit

```bash
git add lib/klass_hero_web/components/provider_components.ex lib/klass_hero_web/live/provider/dashboard_live.ex lib/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema.ex
git commit -m "feat: add enrollment capacity fields to provider program form (#149)"
```

---

## Task 10: Full Integration Test + Precommit

**Files:**
- Run: `mix precommit` (compile --warnings-as-errors, format, test)

### Step 1: Run precommit

Run: `mix precommit`
Expected: Zero warnings, all tests pass, code formatted

### Step 2: Fix any warnings or failures

Address any remaining issues found by the precommit check.

### Step 3: Final commit if any fixes needed

```bash
git add -A
git commit -m "chore: fix warnings and formatting for enrollment capacity (#149)"
```
