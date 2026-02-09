# Staff Member Profiles Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable providers to create, manage, and publicly display staff/team member profiles (issue #44).

**Architecture:** Follows existing Identity bounded context DDD + Ports & Adapters. Domain model → port → use cases → Ecto adapter → LiveView dashboard CRUD → public section on ProgramDetailLive. Tags share vocabulary with ProgramCategories.

**Tech Stack:** Elixir, Phoenix LiveView, Ecto, PostgreSQL, Tailwind CSS

---

## Task 1: StaffMember Domain Model

**Files:**
- Create: `lib/klass_hero/identity/domain/models/staff_member.ex`
- Test: `test/klass_hero/identity/domain/models/staff_member_test.exs`

**Reference:** `lib/klass_hero/identity/domain/models/child.ex` (same pattern)

**Step 1: Write the failing test**

```elixir
# test/klass_hero/identity/domain/models/staff_member_test.exs
defmodule KlassHero.Identity.Domain.Models.StaffMemberTest do
  use ExUnit.Case, async: true

  alias KlassHero.Identity.Domain.Models.StaffMember

  @valid_attrs %{
    id: "550e8400-e29b-41d4-a716-446655440000",
    provider_id: "660e8400-e29b-41d4-a716-446655440001",
    first_name: "Mike",
    last_name: "Johnson"
  }

  describe "new/1 with valid attributes" do
    test "creates staff member with required fields only" do
      assert {:ok, staff} = StaffMember.new(@valid_attrs)
      assert staff.first_name == "Mike"
      assert staff.last_name == "Johnson"
      assert staff.tags == []
      assert staff.qualifications == []
      assert staff.active == true
    end

    test "creates staff member with all fields" do
      attrs = Map.merge(@valid_attrs, %{
        role: "Head Coach",
        email: "mike@example.com",
        bio: "10 years coaching experience.",
        headshot_url: "https://example.com/photo.jpg",
        tags: ["sports"],
        qualifications: ["First Aid", "UEFA B License"],
        active: true
      })

      assert {:ok, staff} = StaffMember.new(attrs)
      assert staff.role == "Head Coach"
      assert staff.tags == ["sports"]
      assert staff.qualifications == ["First Aid", "UEFA B License"]
    end
  end

  describe "new/1 validation errors" do
    test "rejects empty first_name" do
      assert {:error, errors} = StaffMember.new(%{@valid_attrs | first_name: ""})
      assert "First name cannot be empty" in errors
    end

    test "rejects empty last_name" do
      assert {:error, errors} = StaffMember.new(%{@valid_attrs | last_name: ""})
      assert "Last name cannot be empty" in errors
    end

    test "rejects empty provider_id" do
      assert {:error, errors} = StaffMember.new(%{@valid_attrs | provider_id: ""})
      assert "Provider ID cannot be empty" in errors
    end

    test "rejects invalid tag" do
      attrs = Map.put(@valid_attrs, :tags, ["sports", "invalid_tag"])
      assert {:error, errors} = StaffMember.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "invalid_tag"))
    end

    test "rejects first_name over 100 characters" do
      long = String.duplicate("a", 101)
      assert {:error, errors} = StaffMember.new(%{@valid_attrs | first_name: long})
      assert "First name must be 100 characters or less" in errors
    end
  end

  describe "full_name/1" do
    test "returns first + last" do
      {:ok, staff} = StaffMember.new(@valid_attrs)
      assert StaffMember.full_name(staff) == "Mike Johnson"
    end
  end

  describe "initials/1" do
    test "returns first letter of each name" do
      {:ok, staff} = StaffMember.new(@valid_attrs)
      assert StaffMember.initials(staff) == "MJ"
    end
  end

  describe "from_persistence/1" do
    test "reconstructs without validation" do
      attrs = Map.merge(@valid_attrs, %{
        tags: [], qualifications: [], active: true,
        inserted_at: ~U[2025-01-01 12:00:00Z],
        updated_at: ~U[2025-01-01 12:00:00Z]
      })
      assert {:ok, staff} = StaffMember.from_persistence(attrs)
      assert staff.first_name == "Mike"
    end

    test "errors on missing enforce key" do
      assert {:error, :invalid_persistence_data} =
        StaffMember.from_persistence(%{id: "abc", first_name: "X"})
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/identity/domain/models/staff_member_test.exs`
Expected: compilation error — StaffMember module doesn't exist

**Step 3: Write the domain model**

```elixir
# lib/klass_hero/identity/domain/models/staff_member.ex
defmodule KlassHero.Identity.Domain.Models.StaffMember do
  @moduledoc """
  Pure domain entity representing a staff/team member in the Identity bounded context.

  Staff members belong to a provider and are visible to parents on program pages.
  Contains only business logic and validation rules, no database dependencies.

  Tags use the same vocabulary as program categories (ProgramCategories.program_categories/0).
  Qualifications are freeform text entries (e.g., "First Aid", "UEFA B License").
  """

  alias KlassHero.ProgramCatalog.Domain.Services.ProgramCategories

  @enforce_keys [:id, :provider_id, :first_name, :last_name]

  defstruct [
    :id,
    :provider_id,
    :first_name,
    :last_name,
    :role,
    :email,
    :bio,
    :headshot_url,
    tags: [],
    qualifications: [],
    active: true,
    inserted_at: nil,
    updated_at: nil
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          provider_id: String.t(),
          first_name: String.t(),
          last_name: String.t(),
          role: String.t() | nil,
          email: String.t() | nil,
          bio: String.t() | nil,
          headshot_url: String.t() | nil,
          tags: [String.t()],
          qualifications: [String.t()],
          active: boolean(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  def new(attrs) do
    attrs_with_defaults = apply_defaults(attrs)
    staff = struct!(__MODULE__, attrs_with_defaults)

    case validate(staff) do
      [] -> {:ok, staff}
      errors -> {:error, errors}
    end
  end

  def from_persistence(attrs) when is_map(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    ArgumentError -> {:error, :invalid_persistence_data}
  end

  def valid?(%__MODULE__{} = staff), do: validate(staff) == []

  def full_name(%__MODULE__{first_name: first, last_name: last}), do: "#{first} #{last}"

  def initials(%__MODULE__{first_name: first, last_name: last}) do
    f = String.first(first || "") |> String.upcase()
    l = String.first(last || "") |> String.upcase()
    "#{f}#{l}"
  end

  defp apply_defaults(attrs) do
    attrs
    |> Map.put_new(:tags, [])
    |> Map.put_new(:qualifications, [])
    |> Map.put_new(:active, true)
  end

  defp validate(%__MODULE__{} = staff) do
    []
    |> validate_provider_id(staff.provider_id)
    |> validate_first_name(staff.first_name)
    |> validate_last_name(staff.last_name)
    |> validate_role(staff.role)
    |> validate_email(staff.email)
    |> validate_bio(staff.bio)
    |> validate_headshot_url(staff.headshot_url)
    |> validate_tags(staff.tags)
    |> validate_qualifications(staff.qualifications)
  end

  defp validate_provider_id(errors, id) when is_binary(id) do
    if String.trim(id) == "", do: ["Provider ID cannot be empty" | errors], else: errors
  end
  defp validate_provider_id(errors, _), do: ["Provider ID must be a string" | errors]

  defp validate_first_name(errors, name) when is_binary(name) do
    trimmed = String.trim(name)
    cond do
      trimmed == "" -> ["First name cannot be empty" | errors]
      String.length(trimmed) > 100 -> ["First name must be 100 characters or less" | errors]
      true -> errors
    end
  end
  defp validate_first_name(errors, _), do: ["First name must be a string" | errors]

  defp validate_last_name(errors, name) when is_binary(name) do
    trimmed = String.trim(name)
    cond do
      trimmed == "" -> ["Last name cannot be empty" | errors]
      String.length(trimmed) > 100 -> ["Last name must be 100 characters or less" | errors]
      true -> errors
    end
  end
  defp validate_last_name(errors, _), do: ["Last name must be a string" | errors]

  defp validate_role(errors, nil), do: errors
  defp validate_role(errors, role) when is_binary(role) do
    if String.length(role) > 100, do: ["Role must be 100 characters or less" | errors], else: errors
  end
  defp validate_role(errors, _), do: ["Role must be a string" | errors]

  defp validate_email(errors, nil), do: errors
  defp validate_email(errors, email) when is_binary(email) do
    trimmed = String.trim(email)
    cond do
      trimmed == "" -> ["Email cannot be empty if provided" | errors]
      not String.contains?(trimmed, "@") -> ["Email must contain @" | errors]
      String.length(trimmed) > 255 -> ["Email must be 255 characters or less" | errors]
      true -> errors
    end
  end
  defp validate_email(errors, _), do: ["Email must be a string" | errors]

  defp validate_bio(errors, nil), do: errors
  defp validate_bio(errors, bio) when is_binary(bio) do
    if String.length(bio) > 2000, do: ["Bio must be 2000 characters or less" | errors], else: errors
  end
  defp validate_bio(errors, _), do: ["Bio must be a string" | errors]

  defp validate_headshot_url(errors, nil), do: errors
  defp validate_headshot_url(errors, url) when is_binary(url) do
    if String.length(url) > 500, do: ["Headshot URL must be 500 characters or less" | errors], else: errors
  end
  defp validate_headshot_url(errors, _), do: ["Headshot URL must be a string" | errors]

  defp validate_tags(errors, tags) when is_list(tags) do
    valid = ProgramCategories.program_categories()
    invalid = Enum.reject(tags, &(&1 in valid))
    if invalid == [], do: errors, else: ["Invalid tags: #{Enum.join(invalid, ", ")}" | errors]
  end
  defp validate_tags(errors, _), do: ["Tags must be a list" | errors]

  defp validate_qualifications(errors, quals) when is_list(quals) do
    if Enum.all?(quals, &is_binary/1), do: errors, else: ["Qualifications must be a list of strings" | errors]
  end
  defp validate_qualifications(errors, _), do: ["Qualifications must be a list" | errors]
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/identity/domain/models/staff_member_test.exs`
Expected: all tests PASS

**Step 5: Commit**

```bash
git add lib/klass_hero/identity/domain/models/staff_member.ex test/klass_hero/identity/domain/models/staff_member_test.exs
git commit -m "feat(identity): add StaffMember domain model with validation"
```

---

## Task 2: ForStoringStaffMembers Port

**Files:**
- Create: `lib/klass_hero/identity/domain/ports/for_storing_staff_members.ex`

**Reference:** `lib/klass_hero/identity/domain/ports/for_storing_provider_profiles.ex`

**Step 1: Write the port behaviour**

```elixir
# lib/klass_hero/identity/domain/ports/for_storing_staff_members.ex
defmodule KlassHero.Identity.Domain.Ports.ForStoringStaffMembers do
  @moduledoc """
  Repository port for storing and retrieving staff members in the Identity bounded context.

  Defines the contract for staff member persistence.
  Implemented by adapters in the infrastructure layer.
  """

  alias KlassHero.Identity.Domain.Models.StaffMember

  @callback create(attrs :: map()) ::
              {:ok, StaffMember.t()} | {:error, term()}

  @callback get(id :: binary()) ::
              {:ok, StaffMember.t()} | {:error, :not_found}

  @callback list_by_provider(provider_id :: binary()) ::
              {:ok, [StaffMember.t()]}

  @callback update(staff_member :: StaffMember.t()) ::
              {:ok, StaffMember.t()} | {:error, :not_found | term()}

  @callback delete(id :: binary()) ::
              :ok | {:error, :not_found}
end
```

**Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: compiles with zero warnings

**Step 3: Commit**

```bash
git add lib/klass_hero/identity/domain/ports/for_storing_staff_members.ex
git commit -m "feat(identity): add ForStoringStaffMembers port behaviour"
```

---

## Task 3: Use Cases (Create, Update, Delete)

**Files:**
- Create: `lib/klass_hero/identity/application/use_cases/staff_members/create_staff_member.ex`
- Create: `lib/klass_hero/identity/application/use_cases/staff_members/update_staff_member.ex`
- Create: `lib/klass_hero/identity/application/use_cases/staff_members/delete_staff_member.ex`

**Reference:** `lib/klass_hero/identity/application/use_cases/providers/create_provider_profile.ex`, `update_provider_profile.ex`, `lib/klass_hero/identity/application/use_cases/children/delete_child.ex`

**Step 1: Write CreateStaffMember use case**

```elixir
# lib/klass_hero/identity/application/use_cases/staff_members/create_staff_member.ex
defmodule KlassHero.Identity.Application.UseCases.StaffMembers.CreateStaffMember do
  @moduledoc """
  Use case for creating a new staff member.

  Orchestrates domain validation and persistence through the repository port.
  """

  alias KlassHero.Identity.Domain.Models.StaffMember

  @repository Application.compile_env!(:klass_hero, [:identity, :for_storing_staff_members])

  def execute(attrs) when is_map(attrs) do
    attrs_with_id = Map.put_new(attrs, :id, Ecto.UUID.generate())

    with {:ok, _validated} <- StaffMember.new(attrs_with_id),
         {:ok, persisted} <- @repository.create(attrs_with_id) do
      {:ok, persisted}
    else
      {:error, errors} when is_list(errors) -> {:error, {:validation_error, errors}}
      {:error, _} = error -> error
    end
  end
end
```

**Step 2: Write UpdateStaffMember use case**

```elixir
# lib/klass_hero/identity/application/use_cases/staff_members/update_staff_member.ex
defmodule KlassHero.Identity.Application.UseCases.StaffMembers.UpdateStaffMember do
  @moduledoc """
  Use case for updating an existing staff member.

  Loads the staff member, merges updated fields, validates, then persists.
  """

  alias KlassHero.Identity.Domain.Models.StaffMember

  @repository Application.compile_env!(:klass_hero, [:identity, :for_storing_staff_members])

  @allowed_fields ~w(first_name last_name role email bio headshot_url tags qualifications active)a

  def execute(staff_id, attrs) when is_binary(staff_id) and is_map(attrs) do
    attrs = Map.take(attrs, @allowed_fields)

    with {:ok, existing} <- @repository.get(staff_id),
         merged = Map.merge(Map.from_struct(existing), attrs),
         {:ok, _validated} <- StaffMember.new(merged),
         # Trigger: domain validation passed
         # Why: update existing struct to preserve timestamps
         # Outcome: persistence layer manages updated_at
         updated = struct(existing, attrs),
         {:ok, persisted} <- @repository.update(updated) do
      {:ok, persisted}
    else
      {:error, errors} when is_list(errors) -> {:error, {:validation_error, errors}}
      {:error, _} = error -> error
    end
  end
end
```

**Step 3: Write DeleteStaffMember use case**

```elixir
# lib/klass_hero/identity/application/use_cases/staff_members/delete_staff_member.ex
defmodule KlassHero.Identity.Application.UseCases.StaffMembers.DeleteStaffMember do
  @moduledoc """
  Use case for deleting a staff member.
  """

  @repository Application.compile_env!(:klass_hero, [:identity, :for_storing_staff_members])

  def execute(staff_id) when is_binary(staff_id) do
    @repository.delete(staff_id)
  end
end
```

**Step 4: Verify compilation**

NOTE: These will NOT compile yet because `config.exs` doesn't have the `:for_storing_staff_members` key. That's fine — they compile when the config is added in Task 5. Skip compilation check for now.

**Step 5: Commit**

```bash
git add lib/klass_hero/identity/application/use_cases/staff_members/
git commit -m "feat(identity): add staff member CRUD use cases"
```

---

## Task 4: Migration + Ecto Schema + Mapper + Repository + Change Module

**Files:**
- Create: `priv/repo/migrations/*_create_staff_members.exs` (via `mix ecto.gen.migration`)
- Create: `lib/klass_hero/identity/adapters/driven/persistence/schemas/staff_member_schema.ex`
- Create: `lib/klass_hero/identity/adapters/driven/persistence/mappers/staff_member_mapper.ex`
- Create: `lib/klass_hero/identity/adapters/driven/persistence/repositories/staff_member_repository.ex`
- Create: `lib/klass_hero/identity/adapters/driven/persistence/change_staff_member.ex`

**Reference:**
- Schema: `lib/klass_hero/identity/adapters/driven/persistence/schemas/provider_profile_schema.ex`
- Mapper: `lib/klass_hero/identity/adapters/driven/persistence/mappers/provider_profile_mapper.ex`
- Mapper helpers: `lib/klass_hero/identity/adapters/driven/persistence/mappers/mapper_helpers.ex`
- Repository: `lib/klass_hero/identity/adapters/driven/persistence/repositories/provider_profile_repository.ex`
- Change: `lib/klass_hero/identity/adapters/driven/persistence/change_provider_profile.ex`

**Step 1: Generate migration**

Run: `mix ecto.gen.migration create_staff_members`

**Step 2: Write the migration**

```elixir
# priv/repo/migrations/<timestamp>_create_staff_members.exs
defmodule KlassHero.Repo.Migrations.CreateStaffMembers do
  use Ecto.Migration

  def change do
    create table(:staff_members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider_id, references(:providers, type: :binary_id, on_delete: :delete_all), null: false
      add :first_name, :string, null: false, size: 100
      add :last_name, :string, null: false, size: 100
      add :role, :string, size: 100
      add :email, :string, size: 255
      add :bio, :text
      add :headshot_url, :string
      add :tags, {:array, :string}, default: [], null: false
      add :qualifications, {:array, :string}, default: [], null: false
      add :active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:staff_members, [:provider_id])
  end
end
```

**Step 3: Run migration**

Run: `mix ecto.migrate`
Expected: migration succeeds

**Step 4: Write the Ecto schema**

```elixir
# lib/klass_hero/identity/adapters/driven/persistence/schemas/staff_member_schema.ex
defmodule KlassHero.Identity.Adapters.Driven.Persistence.Schemas.StaffMemberSchema do
  @moduledoc """
  Ecto schema for the staff_members table.

  Use StaffMemberMapper to convert between this schema and domain StaffMember entities.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias KlassHero.ProgramCatalog.Domain.Services.ProgramCategories

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  schema "staff_members" do
    field :provider_id, :binary_id
    field :first_name, :string
    field :last_name, :string
    field :role, :string
    field :email, :string
    field :bio, :string
    field :headshot_url, :string
    field :tags, {:array, :string}, default: []
    field :qualifications, {:array, :string}, default: []
    field :active, :boolean, default: true

    timestamps()
  end

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [
      :provider_id, :first_name, :last_name, :role, :email,
      :bio, :headshot_url, :tags, :qualifications, :active
    ])
    |> validate_required([:provider_id, :first_name, :last_name])
    |> validate_length(:first_name, min: 1, max: 100)
    |> validate_length(:last_name, min: 1, max: 100)
    |> validate_length(:role, max: 100)
    |> validate_length(:email, max: 255)
    |> validate_length(:bio, max: 2000)
    |> validate_length(:headshot_url, max: 500)
    |> validate_tags()
    |> foreign_key_constraint(:provider_id)
  end

  @doc """
  Form changeset for editing staff members via LiveView.
  Excludes provider_id (set programmatically, not editable).
  """
  def edit_changeset(schema, attrs) do
    schema
    |> cast(attrs, [
      :first_name, :last_name, :role, :email,
      :bio, :tags, :qualifications, :active
    ])
    |> validate_required([:first_name, :last_name])
    |> validate_length(:first_name, min: 1, max: 100)
    |> validate_length(:last_name, min: 1, max: 100)
    |> validate_length(:role, max: 100)
    |> validate_length(:email, max: 255)
    |> validate_length(:bio, max: 2000)
    |> validate_tags()
  end

  defp validate_tags(changeset) do
    case get_change(changeset, :tags) do
      nil -> changeset
      tags ->
        valid = ProgramCategories.program_categories()
        invalid = Enum.reject(tags, &(&1 in valid))
        if invalid == [] do
          changeset
        else
          add_error(changeset, :tags, "contains invalid tags: #{Enum.join(invalid, ", ")}")
        end
    end
  end
end
```

**Step 5: Write the mapper**

```elixir
# lib/klass_hero/identity/adapters/driven/persistence/mappers/staff_member_mapper.ex
defmodule KlassHero.Identity.Adapters.Driven.Persistence.Mappers.StaffMemberMapper do
  @moduledoc """
  Maps between domain StaffMember entities and StaffMemberSchema Ecto structs.
  """

  import KlassHero.Identity.Adapters.Driven.Persistence.Mappers.MapperHelpers,
    only: [maybe_add_id: 2]

  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.StaffMemberSchema
  alias KlassHero.Identity.Domain.Models.StaffMember

  def to_domain(%StaffMemberSchema{} = schema) do
    %StaffMember{
      id: to_string(schema.id),
      provider_id: to_string(schema.provider_id),
      first_name: schema.first_name,
      last_name: schema.last_name,
      role: schema.role,
      email: schema.email,
      bio: schema.bio,
      headshot_url: schema.headshot_url,
      tags: schema.tags || [],
      qualifications: schema.qualifications || [],
      active: schema.active,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  def to_schema(%StaffMember{} = staff) do
    %{
      provider_id: staff.provider_id,
      first_name: staff.first_name,
      last_name: staff.last_name,
      role: staff.role,
      email: staff.email,
      bio: staff.bio,
      headshot_url: staff.headshot_url,
      tags: staff.tags,
      qualifications: staff.qualifications,
      active: staff.active
    }
    |> maybe_add_id(staff.id)
  end

  def to_domain_list(schemas) when is_list(schemas), do: Enum.map(schemas, &to_domain/1)
end
```

**Step 6: Write the repository**

```elixir
# lib/klass_hero/identity/adapters/driven/persistence/repositories/staff_member_repository.ex
defmodule KlassHero.Identity.Adapters.Driven.Persistence.Repositories.StaffMemberRepository do
  @moduledoc """
  Repository implementation for storing and retrieving staff members.

  Implements the ForStoringStaffMembers port.
  """

  @behaviour KlassHero.Identity.Domain.Ports.ForStoringStaffMembers

  import Ecto.Query

  alias KlassHero.Identity.Adapters.Driven.Persistence.Mappers.StaffMemberMapper
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.StaffMemberSchema
  alias KlassHero.Repo

  require Logger

  @impl true
  def create(attrs) when is_map(attrs) do
    %StaffMemberSchema{}
    |> StaffMemberSchema.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} ->
        {:ok, StaffMemberMapper.to_domain(schema)}

      {:error, changeset} ->
        Logger.warning("[Identity.StaffMemberRepository] Validation error creating staff member",
          provider_id: attrs[:provider_id],
          errors: inspect(changeset.errors)
        )
        {:error, changeset}
    end
  end

  @impl true
  def get(id) when is_binary(id) do
    case Repo.get(StaffMemberSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, StaffMemberMapper.to_domain(schema)}
    end
  end

  @impl true
  def list_by_provider(provider_id) when is_binary(provider_id) do
    members =
      StaffMemberSchema
      |> where([s], s.provider_id == ^provider_id)
      |> order_by([s], asc: s.inserted_at)
      |> Repo.all()
      |> StaffMemberMapper.to_domain_list()

    {:ok, members}
  end

  @impl true
  def update(staff_member) do
    case Repo.get(StaffMemberSchema, staff_member.id) do
      nil ->
        {:error, :not_found}

      schema ->
        attrs = StaffMemberMapper.to_schema(staff_member)

        with {:ok, updated} <-
               schema
               |> StaffMemberSchema.changeset(attrs)
               |> Repo.update() do
          {:ok, StaffMemberMapper.to_domain(updated)}
        end
    end
  end

  @impl true
  def delete(id) when is_binary(id) do
    case Repo.get(StaffMemberSchema, id) do
      nil -> {:error, :not_found}
      schema ->
        {:ok, _} = Repo.delete(schema)
        :ok
    end
  end
end
```

**Step 7: Write the change module (for LiveView forms)**

```elixir
# lib/klass_hero/identity/adapters/driven/persistence/change_staff_member.ex
defmodule KlassHero.Identity.Adapters.Driven.Persistence.ChangeStaffMember do
  @moduledoc """
  Adapter for building staff member form changesets.

  Converts domain StaffMember structs to persistence schemas and produces
  changesets for LiveView form tracking.
  """

  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.StaffMemberSchema
  alias KlassHero.Identity.Domain.Models.StaffMember

  def execute(%StaffMember{} = staff, attrs \\ %{}) do
    staff |> staff_to_schema() |> StaffMemberSchema.edit_changeset(attrs)
  end

  @doc """
  Returns an empty changeset for creating a new staff member form.
  """
  def new_changeset(attrs \\ %{}) do
    %StaffMemberSchema{} |> StaffMemberSchema.edit_changeset(attrs)
  end

  defp staff_to_schema(%StaffMember{} = staff) do
    %StaffMemberSchema{
      id: staff.id,
      provider_id: staff.provider_id,
      first_name: staff.first_name,
      last_name: staff.last_name,
      role: staff.role,
      email: staff.email,
      bio: staff.bio,
      headshot_url: staff.headshot_url,
      tags: staff.tags,
      qualifications: staff.qualifications,
      active: staff.active
    }
  end
end
```

**Step 8: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Will NOT compile yet (config key missing). Proceed to Task 5.

**Step 9: Commit**

```bash
git add priv/repo/migrations/*_create_staff_members.exs \
  lib/klass_hero/identity/adapters/driven/persistence/schemas/staff_member_schema.ex \
  lib/klass_hero/identity/adapters/driven/persistence/mappers/staff_member_mapper.ex \
  lib/klass_hero/identity/adapters/driven/persistence/repositories/staff_member_repository.ex \
  lib/klass_hero/identity/adapters/driven/persistence/change_staff_member.ex
git commit -m "feat(identity): add staff member persistence layer (schema, repo, mapper)"
```

---

## Task 5: Wire into Identity Facade + Config

**Files:**
- Modify: `config/config.exs:75-86` (add config key)
- Modify: `lib/klass_hero/identity.ex` (add public API)
- Modify: `test/support/fixtures/identity_fixtures.ex` (add fixture)

**Reference:** Existing Identity facade pattern in `lib/klass_hero/identity.ex:1-50`

**Step 1: Add config key**

In `config/config.exs`, add `for_storing_staff_members:` to the `:identity` config block (after line 86, before the closing of that config):

```elixir
# In config :klass_hero, :identity block, add:
  for_storing_staff_members:
    KlassHero.Identity.Adapters.Driven.Persistence.Repositories.StaffMemberRepository
```

**Step 2: Add facade functions to Identity module**

Add these aliases and module attribute at the top of `lib/klass_hero/identity.ex` (alongside existing aliases):

```elixir
alias KlassHero.Identity.Adapters.Driven.Persistence.ChangeStaffMember
alias KlassHero.Identity.Application.UseCases.StaffMembers.CreateStaffMember
alias KlassHero.Identity.Application.UseCases.StaffMembers.DeleteStaffMember
alias KlassHero.Identity.Application.UseCases.StaffMembers.UpdateStaffMember
alias KlassHero.Identity.Domain.Models.StaffMember

# Add module attribute:
@staff_repository Application.compile_env!(:klass_hero, [:identity, :for_storing_staff_members])
```

Add these public functions (grouped together in a "Staff Members" section):

```elixir
  # ============================================================================
  # Staff Members
  # ============================================================================

  def create_staff_member(attrs) when is_map(attrs) do
    CreateStaffMember.execute(attrs)
  end

  def update_staff_member(staff_id, attrs) when is_binary(staff_id) and is_map(attrs) do
    UpdateStaffMember.execute(staff_id, attrs)
  end

  def delete_staff_member(staff_id) when is_binary(staff_id) do
    DeleteStaffMember.execute(staff_id)
  end

  def get_staff_member(staff_id) when is_binary(staff_id) do
    @staff_repository.get(staff_id)
  end

  def list_staff_members(provider_id) when is_binary(provider_id) do
    @staff_repository.list_by_provider(provider_id)
  end

  def change_staff_member(%StaffMember{} = staff, attrs \\ %{}) do
    ChangeStaffMember.execute(staff, attrs)
  end

  def new_staff_member_changeset(attrs \\ %{}) do
    ChangeStaffMember.new_changeset(attrs)
  end
```

**Step 3: Add test fixture**

Append to `test/support/fixtures/identity_fixtures.ex`:

```elixir
  alias KlassHero.Identity.Adapters.Driven.Persistence.Mappers.StaffMemberMapper
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.StaffMemberSchema

  def staff_member_fixture(attrs \\ %{}) do
    defaults = %{
      provider_id: attrs[:provider_id] || provider_profile_fixture().id,
      first_name: "Staff #{System.unique_integer([:positive])}",
      last_name: "Member"
    }

    merged = Map.merge(defaults, Map.new(attrs))

    {:ok, schema} =
      %StaffMemberSchema{}
      |> StaffMemberSchema.changeset(merged)
      |> Repo.insert()

    StaffMemberMapper.to_domain(schema)
  end
```

**Step 4: Verify compilation and run existing tests**

Run: `mix compile --warnings-as-errors`
Expected: zero warnings

Run: `mix test`
Expected: all existing tests pass

**Step 5: Write integration test**

```elixir
# test/klass_hero/identity/staff_member_integration_test.exs
defmodule KlassHero.Identity.StaffMemberIntegrationTest do
  use KlassHero.DataCase

  alias KlassHero.Identity
  alias KlassHero.IdentityFixtures

  describe "create_staff_member/1" do
    test "creates with valid attrs" do
      provider = IdentityFixtures.provider_profile_fixture()

      assert {:ok, staff} =
               Identity.create_staff_member(%{
                 provider_id: provider.id,
                 first_name: "Mike",
                 last_name: "Johnson",
                 role: "Head Coach",
                 tags: ["sports"],
                 qualifications: ["First Aid"]
               })

      assert staff.first_name == "Mike"
      assert staff.tags == ["sports"]
    end

    test "rejects invalid tags" do
      provider = IdentityFixtures.provider_profile_fixture()

      assert {:error, {:validation_error, errors}} =
               Identity.create_staff_member(%{
                 provider_id: provider.id,
                 first_name: "Mike",
                 last_name: "Johnson",
                 tags: ["invalid_category"]
               })

      assert Enum.any?(errors, &String.contains?(&1, "invalid_category"))
    end
  end

  describe "list_staff_members/1" do
    test "returns staff for provider" do
      provider = IdentityFixtures.provider_profile_fixture()
      _staff = IdentityFixtures.staff_member_fixture(provider_id: provider.id, first_name: "Alice")

      assert {:ok, [member]} = Identity.list_staff_members(provider.id)
      assert member.first_name == "Alice"
    end

    test "returns empty list for provider with no staff" do
      provider = IdentityFixtures.provider_profile_fixture()
      assert {:ok, []} = Identity.list_staff_members(provider.id)
    end
  end

  describe "update_staff_member/2" do
    test "updates allowed fields" do
      staff = IdentityFixtures.staff_member_fixture(first_name: "Old", role: "Assistant")

      assert {:ok, updated} = Identity.update_staff_member(staff.id, %{role: "Head Coach"})
      assert updated.role == "Head Coach"
      assert updated.first_name == "Old"
    end
  end

  describe "delete_staff_member/1" do
    test "deletes existing staff member" do
      staff = IdentityFixtures.staff_member_fixture()
      assert :ok = Identity.delete_staff_member(staff.id)
      assert {:error, :not_found} = Identity.get_staff_member(staff.id)
    end

    test "returns not_found for missing id" do
      assert {:error, :not_found} = Identity.delete_staff_member(Ecto.UUID.generate())
    end
  end
end
```

**Step 6: Run integration tests**

Run: `mix test test/klass_hero/identity/staff_member_integration_test.exs`
Expected: all PASS

**Step 7: Run full test suite**

Run: `mix test`
Expected: all PASS

**Step 8: Commit**

```bash
git add config/config.exs lib/klass_hero/identity.ex \
  test/support/fixtures/identity_fixtures.ex \
  test/klass_hero/identity/staff_member_integration_test.exs
git commit -m "feat(identity): wire staff members into Identity facade with integration tests"
```

---

## Task 6: StaffMember Presenter

**Files:**
- Create: `lib/klass_hero_web/presenters/staff_member_presenter.ex`

**Reference:** `lib/klass_hero_web/presenters/provider_presenter.ex`

**Step 1: Write the presenter**

```elixir
# lib/klass_hero_web/presenters/staff_member_presenter.ex
defmodule KlassHeroWeb.Presenters.StaffMemberPresenter do
  @moduledoc """
  Transforms StaffMember domain models to view-ready formats.
  """

  alias KlassHero.Identity.Domain.Models.StaffMember

  def to_card_view(%StaffMember{} = staff) do
    %{
      id: staff.id,
      full_name: StaffMember.full_name(staff),
      initials: StaffMember.initials(staff),
      first_name: staff.first_name,
      last_name: staff.last_name,
      role: staff.role,
      email: staff.email,
      bio: staff.bio,
      headshot_url: staff.headshot_url,
      tags: staff.tags || [],
      qualifications: staff.qualifications || [],
      active: staff.active
    }
  end

  def to_card_view_list(staff_members) when is_list(staff_members) do
    Enum.map(staff_members, &to_card_view/1)
  end
end
```

**Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: zero warnings

**Step 3: Commit**

```bash
git add lib/klass_hero_web/presenters/staff_member_presenter.ex
git commit -m "feat(web): add StaffMemberPresenter for view transformations"
```

---

## Task 7: Dashboard LiveView — Wire Real Data + CRUD Events

**Files:**
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex`
- Modify: `lib/klass_hero_web/components/provider_components.ex`

**Reference:**
- Current dashboard: `lib/klass_hero_web/live/provider/dashboard_live.ex:26-78` (mount)
- Upload pattern: `lib/klass_hero_web/live/provider/dashboard_live.ex:528-540` (upload_logo)
- Team card component: `lib/klass_hero_web/components/provider_components.ex:390-468`
- ProgramCategories: `lib/klass_hero/program_catalog/domain/services/program_categories.ex`

This is the largest task. Implementation details for the LiveView CRUD handlers, the form modal component, and the updated team card component should follow these patterns:

**Step 1: Update mount to use real data**

In `dashboard_live.ex` mount, replace:
```elixir
team = MockData.team()
staff_options = MockData.staff_options()
```
With:
```elixir
{:ok, staff_members} = Identity.list_staff_members(provider_profile.id)
staff_views = StaffMemberPresenter.to_card_view_list(staff_members)
```
And replace `assign(team: team)` with `stream(:team_members, staff_views)`.
Remove `staff_options` assign (no longer needed for mock dropdown).

Add upload registration:
```elixir
|> allow_upload(:headshot, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1, max_file_size: 1_000_000)
```

Add assigns for the modal state:
```elixir
|> assign(show_staff_modal: false, editing_staff_id: nil)
|> assign(staff_form: to_form(Identity.new_staff_member_changeset()))
```

**Step 2: Add handle_params for :team action**

```elixir
def handle_params(_params, _uri, %{assigns: %{live_action: :team}} = socket) do
  provider = socket.assigns.current_scope.provider

  {:ok, staff_members} = Identity.list_staff_members(provider.id)
  staff_views = StaffMemberPresenter.to_card_view_list(staff_members)

  {:noreply,
   socket
   |> stream(:team_members, staff_views, reset: true)
   |> assign(staff_count: length(staff_members))}
end
```

**Step 3: Add CRUD event handlers**

- `"add_member"` — set `show_staff_modal: true`, `editing_staff_id: nil`, fresh form
- `"edit_member"` — load staff by ID, set `editing_staff_id`, pre-fill form
- `"close_staff_modal"` — set `show_staff_modal: false`
- `"validate_staff"` — changeset validation via `Identity.change_staff_member/2` or `Identity.new_staff_member_changeset/1`
- `"save_staff"` — branch on `editing_staff_id`: nil → create, non-nil → update; handle headshot upload (same pattern as `upload_logo`); stream_insert new/updated member; close modal
- `"delete_member"` — call `Identity.delete_staff_member/1`, stream_delete from `:team_members`

**Step 4: Update team_member_card component**

In `provider_components.ex`, update `team_member_card/1`:
- Show `headshot_url` image with fallback to initials avatar
- Render tags as colored category pills
- Render qualifications as badge pills
- Wire Edit button: `phx-click="edit_member" phx-value-id={@member.id}`
- Wire Delete button: `phx-click="delete_member" phx-value-id={@member.id}` with `data-confirm`

**Step 5: Add staff_member_form_modal component**

New component `staff_member_form_modal/1` in `provider_components.ex`:
- Uses `<.modal>` from core_components
- `<.form>` with `phx-change="validate_staff"` and `phx-submit="save_staff"`
- Fields: first_name, last_name, role, email (all `<.input type="text">`)
- Bio: `<.input type="textarea">`
- Tags: checkboxes from `ProgramCategories.program_categories()`
- Qualifications: text input with "Add" button (dynamic list, managed via `phx-click` to add/remove)
- Headshot: `live_file_input` with preview (same pattern as logo upload)

**Step 6: Update template to use new components**

In the `:team` tab section of the template, replace mock data rendering with:
```heex
<div id="team-members" phx-update="stream">
  <div class="hidden only:block">
    <%!-- Empty state --%>
    <p>{gettext("No team members yet. Add your first staff member!")}</p>
  </div>
  <div :for={{id, member} <- @streams.team_members} id={id}>
    <.team_member_card member={member} />
  </div>
</div>

<%= if @show_staff_modal do %>
  <.staff_member_form_modal
    form={@staff_form}
    editing={@editing_staff_id != nil}
    uploads={@uploads}
  />
<% end %>
```

**Step 7: Run precommit**

Run: `mix precommit`
Expected: compiles, formats, all tests pass

**Step 8: Commit**

```bash
git add lib/klass_hero_web/live/provider/dashboard_live.ex \
  lib/klass_hero_web/components/provider_components.ex
git commit -m "feat(web): wire staff member CRUD into provider dashboard team tab"
```

---

## Task 8: Dashboard LiveView Tests

**Files:**
- Create: `test/klass_hero_web/live/provider/dashboard_team_test.exs`

**Step 1: Write team tab tests**

Test cases to cover:
- Team tab shows "No team members yet" when empty
- Team tab shows staff member cards when members exist
- "Add Member" button opens modal
- Submitting form creates staff member and shows card
- Edit button opens pre-filled modal
- Delete button removes card
- Validation errors display in form

Use `IdentityFixtures.provider_profile_fixture/1` and `IdentityFixtures.staff_member_fixture/1`.
Use `Phoenix.LiveViewTest` assertions: `has_element?/2`, `render_click/2`, `render_submit/2`.

**Step 2: Run tests**

Run: `mix test test/klass_hero_web/live/provider/dashboard_team_test.exs`
Expected: all PASS

**Step 3: Commit**

```bash
git add test/klass_hero_web/live/provider/dashboard_team_test.exs
git commit -m "test: add LiveView tests for provider dashboard team tab"
```

---

## Task 9: Public View — "Meet the Team" on ProgramDetailLive

**Files:**
- Modify: `lib/klass_hero_web/live/program_detail_live.ex:262-301` ("Meet Your Instructor" section)

**Reference:** Current instructor section uses `sample_instructor()` mock data.

**Step 1: Load real staff in mount**

In the `ProgramDetailLive` mount (or handle_params), after loading the program:
```elixir
{:ok, staff_members} = Identity.list_staff_members(program.provider_id)
staff_views = StaffMemberPresenter.to_card_view_list(staff_members)
```
Assign: `|> assign(team_members: staff_views)`

**Step 2: Replace "Meet Your Instructor" section**

Replace lines 262-301 with a "Meet the Team" section that:
- Shows heading "Meet Your Instructor" if 1 member, "Meet the Team" if multiple
- For each member: headshot/initials, full_name, role, tags as pills, qualifications as badges, bio
- NO email shown (private to provider dashboard)
- If no staff members exist, keep existing `sample_instructor()` behavior or hide section

**Step 3: Remove sample_instructor mock**

Delete the `sample_instructor/0` function that returns hardcoded data.

**Step 4: Run precommit**

Run: `mix precommit`
Expected: compiles, formats, all tests pass

**Step 5: Commit**

```bash
git add lib/klass_hero_web/live/program_detail_live.ex
git commit -m "feat(web): show real staff on program detail public page"
```

---

## Task 10: Cleanup Mock Data

**Files:**
- Modify: `lib/klass_hero_web/live/provider/mock_data.ex` (remove `team/0` and `staff_options/0`)
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex` (remove MockData references if any remain)

**Step 1: Remove unused mock functions**

Remove `MockData.team/0` and `MockData.staff_options/0`. Check if `MockData.stats/0` is still used — if so, keep the module; if not, delete `mock_data.ex` entirely.

**Step 2: Remove MockData alias from dashboard**

If MockData is no longer used at all in dashboard_live.ex, remove the alias.

**Step 3: Run precommit**

Run: `mix precommit`
Expected: zero warnings, all tests pass

**Step 4: Commit**

```bash
git add lib/klass_hero_web/live/provider/mock_data.ex lib/klass_hero_web/live/provider/dashboard_live.ex
git commit -m "chore: remove mock team data, replaced by real staff member persistence"
```

---

## Verification Checklist

After all tasks complete:

1. `mix precommit` — compiles with `--warnings-as-errors`, formats, all tests pass
2. Navigate to `/provider/dashboard/team` — see empty state
3. Click "Add Member" — modal opens with form
4. Fill form (name, role, tags, qualifications, bio) and submit — card appears in grid
5. Click Edit on card — modal opens pre-filled, save updates card
6. Click Delete on card — confirm dialog, card disappears
7. Navigate to `/programs/:id` — "Meet the Team" section shows staff from that provider
8. Staff cards on public page show tags, qualifications, NO email
