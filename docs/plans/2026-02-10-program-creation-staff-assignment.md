# Program Creation with Staff Assignment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable providers to create programs from the dashboard with optional instructor assignment (issue #45).

**Architecture:** ProgramCatalog bounded context gets a creation flow (Instructor VO + port + use case + repo). Domain event promoted to integration event. Dashboard LiveView gets inline form panel (same pattern as staff member CRUD). ACL: ProgramCatalog defines its own Instructor value object populated from Identity at the web layer.

**Tech Stack:** Elixir, Phoenix LiveView, Ecto, PostgreSQL, Tailwind CSS

**Skills:** @idiomatic-elixir, @elixir-ecto-patterns, @phoenix-liveview, @phoenix-pubsub

---

## Task 1: Instructor Value Object

**Files:**
- Create: `lib/klass_hero/program_catalog/domain/models/instructor.ex`
- Test: `test/klass_hero/program_catalog/domain/models/instructor_test.exs`

**Reference:** `lib/klass_hero/identity/domain/models/staff_member.ex` (similar VO pattern)

**Step 1: Write the failing test**

```elixir
# test/klass_hero/program_catalog/domain/models/instructor_test.exs
defmodule KlassHero.ProgramCatalog.Domain.Models.InstructorTest do
  use ExUnit.Case, async: true

  alias KlassHero.ProgramCatalog.Domain.Models.Instructor

  @valid_attrs %{
    id: "550e8400-e29b-41d4-a716-446655440000",
    name: "Mike Johnson",
    headshot_url: "https://example.com/photo.jpg"
  }

  describe "new/1" do
    test "creates instructor with all fields" do
      assert {:ok, instructor} = Instructor.new(@valid_attrs)
      assert instructor.id == @valid_attrs.id
      assert instructor.name == "Mike Johnson"
      assert instructor.headshot_url == "https://example.com/photo.jpg"
    end

    test "creates instructor without headshot" do
      attrs = Map.delete(@valid_attrs, :headshot_url)
      assert {:ok, instructor} = Instructor.new(attrs)
      assert instructor.headshot_url == nil
    end

    test "rejects missing id" do
      assert {:error, errors} = Instructor.new(%{@valid_attrs | id: ""})
      assert "ID cannot be empty" in errors
    end

    test "rejects missing name" do
      assert {:error, errors} = Instructor.new(%{@valid_attrs | name: ""})
      assert "Name cannot be empty" in errors
    end
  end

  describe "from_persistence/1" do
    test "reconstructs without validation" do
      assert {:ok, instructor} = Instructor.from_persistence(@valid_attrs)
      assert instructor.name == "Mike Johnson"
    end

    test "errors on missing enforce key" do
      assert {:error, :invalid_persistence_data} =
               Instructor.from_persistence(%{id: "abc"})
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/program_catalog/domain/models/instructor_test.exs`
Expected: compilation error — Instructor module doesn't exist

**Step 3: Write the value object**

```elixir
# lib/klass_hero/program_catalog/domain/models/instructor.ex
defmodule KlassHero.ProgramCatalog.Domain.Models.Instructor do
  @moduledoc """
  Value object representing an instructor assigned to a program.

  This is ProgramCatalog's own representation of who runs a program — an
  Anti-Corruption Layer (ACL) that prevents Identity's StaffMember from
  leaking into this bounded context.

  Populated at creation time from Identity data via the web layer.
  """

  @enforce_keys [:id, :name]

  defstruct [:id, :name, :headshot_url]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          headshot_url: String.t() | nil
        }

  @spec new(map()) :: {:ok, t()} | {:error, [String.t()]}
  def new(attrs) when is_map(attrs) do
    attrs_with_defaults = Map.put_new(attrs, :headshot_url, nil)

    case validate(attrs_with_defaults) do
      [] -> {:ok, struct!(__MODULE__, attrs_with_defaults)}
      errors -> {:error, errors}
    end
  end

  @spec from_persistence(map()) :: {:ok, t()} | {:error, :invalid_persistence_data}
  def from_persistence(attrs) when is_map(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    ArgumentError -> {:error, :invalid_persistence_data}
  end

  defp validate(attrs) do
    []
    |> validate_id(attrs[:id])
    |> validate_name(attrs[:name])
  end

  defp validate_id(errors, id) when is_binary(id) and byte_size(id) > 0 do
    if String.trim(id) == "", do: ["ID cannot be empty" | errors], else: errors
  end

  defp validate_id(errors, _), do: ["ID cannot be empty" | errors]

  defp validate_name(errors, name) when is_binary(name) and byte_size(name) > 0 do
    if String.trim(name) == "", do: ["Name cannot be empty" | errors], else: errors
  end

  defp validate_name(errors, _), do: ["Name cannot be empty" | errors]
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/program_catalog/domain/models/instructor_test.exs`
Expected: all tests PASS

**Step 5: Commit**

```bash
git add lib/klass_hero/program_catalog/domain/models/instructor.ex test/klass_hero/program_catalog/domain/models/instructor_test.exs
git commit -m "feat(program_catalog): add Instructor value object (ACL)"
```

---

## Task 2: Update Program Domain Model

**Files:**
- Modify: `lib/klass_hero/program_catalog/domain/models/program.ex`
- Test: `test/klass_hero/program_catalog/domain/models/program_test.exs`

**Reference:** Current `program.ex` enforce_keys: `[:id, :title, :description, :category, :schedule, :age_range, :price, :pricing_period, :spots_available]`

**Step 1: Write the failing test**

```elixir
# test/klass_hero/program_catalog/domain/models/program_test.exs
defmodule KlassHero.ProgramCatalog.Domain.Models.ProgramTest do
  use ExUnit.Case, async: true

  alias KlassHero.ProgramCatalog.Domain.Models.{Instructor, Program}

  @minimal_attrs %{
    id: "550e8400-e29b-41d4-a716-446655440000",
    provider_id: "660e8400-e29b-41d4-a716-446655440001",
    title: "Art Adventures",
    description: "Creative art program for kids",
    category: "arts",
    price: Decimal.new("50.00")
  }

  describe "new/1 with relaxed enforce_keys" do
    test "creates program with only required fields" do
      assert {:ok, program} = Program.new(@minimal_attrs)
      assert program.title == "Art Adventures"
      assert program.schedule == nil
      assert program.age_range == nil
      assert program.spots_available == 0
    end

    test "creates program with location" do
      attrs = Map.put(@minimal_attrs, :location, "Community Center, Main St")
      assert {:ok, program} = Program.new(attrs)
      assert program.location == "Community Center, Main St"
    end

    test "creates program with cover_image_url" do
      attrs = Map.put(@minimal_attrs, :cover_image_url, "https://example.com/cover.jpg")
      assert {:ok, program} = Program.new(attrs)
      assert program.cover_image_url == "https://example.com/cover.jpg"
    end

    test "creates program with instructor" do
      {:ok, instructor} = Instructor.new(%{id: "abc", name: "Mike J", headshot_url: nil})
      attrs = Map.put(@minimal_attrs, :instructor, instructor)
      assert {:ok, program} = Program.new(attrs)
      assert program.instructor.name == "Mike J"
    end
  end

  describe "valid?/1" do
    test "valid with minimal fields" do
      {:ok, program} = Program.new(@minimal_attrs)
      assert Program.valid?(program)
    end

    test "invalid with empty title" do
      {:ok, program} = Program.new(@minimal_attrs)
      program = %{program | title: ""}
      refute Program.valid?(program)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/program_catalog/domain/models/program_test.exs`
Expected: FAIL — enforce_keys requires schedule, age_range, etc.

**Step 3: Update the Program module**

In `lib/klass_hero/program_catalog/domain/models/program.ex`:

1. Change `@enforce_keys` to: `[:id, :provider_id, :title, :description, :category, :price]`
2. Add to `defstruct`: `:location`, `:cover_image_url`, `:instructor`
3. Set default: `spots_available: 0`
4. Add to `@type t`: `location: String.t() | nil`, `cover_image_url: String.t() | nil`, `instructor: Instructor.t() | nil`
5. Add `alias KlassHero.ProgramCatalog.Domain.Models.Instructor` at top
6. Update `valid?/1` to not check schedule/age_range (they can be nil now)

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/program_catalog/domain/models/program_test.exs`
Expected: all PASS

**Step 5: Run full test suite to check for regressions**

Run: `mix test`
Expected: all PASS (seeds create programs with all fields so existing tests still work)

**Step 6: Commit**

```bash
git add lib/klass_hero/program_catalog/domain/models/program.ex test/klass_hero/program_catalog/domain/models/program_test.exs
git commit -m "feat(program_catalog): relax Program enforce_keys, add location/cover_image/instructor"
```

---

## Task 3: Domain Events + Integration Events

**Files:**
- Create: `lib/klass_hero/program_catalog/domain/events/program_events.ex`
- Create: `lib/klass_hero/program_catalog/domain/events/program_catalog_integration_events.ex`
- Create: `lib/klass_hero/program_catalog/adapters/driven/events/event_handlers/promote_integration_events.ex`

**Reference:**
- Domain events: `lib/klass_hero/accounts/domain/events/user_events.ex`
- Integration events: `lib/klass_hero/accounts/domain/events/accounts_integration_events.ex`
- Promotion handler: `lib/klass_hero/accounts/adapters/driven/events/event_handlers/promote_integration_events.ex`

**Step 1: Write domain events factory**

```elixir
# lib/klass_hero/program_catalog/domain/events/program_events.ex
defmodule KlassHero.ProgramCatalog.Domain.Events.ProgramEvents do
  @moduledoc """
  Factory module for creating Program domain events.

  ## Events

  - `:program_created` - Emitted when a provider creates a new program
  """

  alias KlassHero.Shared.Domain.Events.DomainEvent

  @aggregate_type :program

  def program_created(program_id, payload \\ %{}, opts \\ [])

  def program_created(program_id, payload, opts)
      when is_binary(program_id) and byte_size(program_id) > 0 do
    base_payload = %{program_id: program_id}

    DomainEvent.new(
      :program_created,
      program_id,
      @aggregate_type,
      Map.merge(base_payload, payload),
      opts
    )
  end

  def program_created(program_id, _payload, _opts) do
    raise ArgumentError,
          "program_created/3 requires a non-empty program_id string, got: #{inspect(program_id)}"
  end
end
```

**Step 2: Write integration events factory**

```elixir
# lib/klass_hero/program_catalog/domain/events/program_catalog_integration_events.ex
defmodule KlassHero.ProgramCatalog.Domain.Events.ProgramCatalogIntegrationEvents do
  @moduledoc """
  Factory module for creating ProgramCatalog integration events.

  Integration events are the public contract between bounded contexts.

  ## Events

  - `:program_created` - Emitted when a new program is created.
    Downstream contexts can react (e.g., notifications).
  """

  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  @source_context :program_catalog
  @entity_type :program

  def program_created(program_id, payload \\ %{}, opts \\ [])

  def program_created(program_id, payload, opts)
      when is_binary(program_id) and byte_size(program_id) > 0 do
    base_payload = %{program_id: program_id}

    IntegrationEvent.new(
      :program_created,
      @source_context,
      @entity_type,
      program_id,
      Map.merge(payload, base_payload),
      opts
    )
  end

  def program_created(program_id, _payload, _opts) do
    raise ArgumentError,
          "program_created/3 requires a non-empty program_id string, got: #{inspect(program_id)}"
  end
end
```

**Step 3: Write promotion handler**

```elixir
# lib/klass_hero/program_catalog/adapters/driven/events/event_handlers/promote_integration_events.ex
defmodule KlassHero.ProgramCatalog.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents do
  @moduledoc """
  Promotes ProgramCatalog domain events to integration events for cross-context communication.

  Registered on the ProgramCatalog DomainEventBus at priority 10.
  """

  alias KlassHero.ProgramCatalog.Domain.Events.ProgramCatalogIntegrationEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.IntegrationEventPublishing

  @spec handle(DomainEvent.t()) :: :ok | {:error, term()}
  def handle(%DomainEvent{event_type: :program_created} = event) do
    # Trigger: program_created domain event dispatched from CreateProgram use case
    # Why: other contexts may need to react to new programs
    # Outcome: publish integration event on PubSub topic integration:program_catalog:program_created
    event.aggregate_id
    |> ProgramCatalogIntegrationEvents.program_created(event.payload)
    |> IntegrationEventPublishing.publish()
  end
end
```

**Step 4: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: zero warnings

**Step 5: Commit**

```bash
git add lib/klass_hero/program_catalog/domain/events/ lib/klass_hero/program_catalog/adapters/driven/events/
git commit -m "feat(program_catalog): add domain + integration events with promotion handler"
```

---

## Task 4: ForCreatingPrograms Port + Migration + Schema + Mapper + Repository

**Files:**
- Create: `lib/klass_hero/program_catalog/domain/ports/for_creating_programs.ex`
- Create: `priv/repo/migrations/*_add_program_creation_fields.exs` (via `mix ecto.gen.migration`)
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema.ex`
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper.ex`
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_repository.ex`

**Reference:**
- Port: `lib/klass_hero/program_catalog/domain/ports/for_updating_programs.ex`
- Schema: `program_schema.ex:18-33` (current fields)
- Mapper: `program_mapper.ex:41-58` (to_domain)

**Step 1: Write the port**

```elixir
# lib/klass_hero/program_catalog/domain/ports/for_creating_programs.ex
defmodule KlassHero.ProgramCatalog.Domain.Ports.ForCreatingPrograms do
  @moduledoc """
  Repository port for creating programs in the Program Catalog bounded context.

  Defines the contract for program creation. Implemented by adapters in
  the infrastructure layer.
  """

  @callback create(attrs :: map()) ::
              {:ok, term()} | {:error, term()}
end
```

**Step 2: Generate and write migration**

Run: `mix ecto.gen.migration add_program_creation_fields`

Then write:

```elixir
defmodule KlassHero.Repo.Migrations.AddProgramCreationFields do
  use Ecto.Migration

  def change do
    alter table(:programs) do
      add :location, :string, size: 255
      add :cover_image_url, :string, size: 500
      add :instructor_id, references(:staff_members, type: :binary_id, on_delete: :nilify_all)
      add :instructor_name, :string, size: 200
      add :instructor_headshot_url, :string, size: 500

      # Relax existing required columns to allow nil (for creation form that omits them)
      modify :schedule, :string, null: true
      modify :age_range, :string, null: true
      modify :pricing_period, :string, null: true
    end

    create index(:programs, [:instructor_id])
  end
end
```

Run: `mix ecto.migrate`
Expected: migration succeeds

**Step 3: Update ProgramSchema**

In `program_schema.ex`, add to schema block:
```elixir
field :location, :string
field :cover_image_url, :string
field :instructor_id, :binary_id
field :instructor_name, :string
field :instructor_headshot_url, :string
```

Add a new `create_changeset/2` function (separate from existing `changeset/2` which requires schedule/age_range/etc.):

```elixir
def create_changeset(program_schema, attrs) do
  program_schema
  |> cast(attrs, [
    :title, :description, :category, :price, :provider_id,
    :location, :cover_image_url,
    :instructor_id, :instructor_name, :instructor_headshot_url,
    :spots_available
  ])
  |> validate_required([:title, :description, :category, :price, :provider_id])
  |> validate_length(:title, min: 1, max: 100)
  |> validate_length(:description, min: 1, max: 500)
  |> validate_length(:location, max: 255)
  |> validate_length(:cover_image_url, max: 500)
  |> validate_length(:instructor_name, max: 200)
  |> validate_inclusion(:category, ProgramCategories.program_categories())
  |> validate_number(:price, greater_than_or_equal_to: 0)
  |> validate_number(:spots_available, greater_than_or_equal_to: 0)
  |> foreign_key_constraint(:provider_id)
  |> foreign_key_constraint(:instructor_id)
end
```

Also add `:location`, `:cover_image_url`, `:instructor_id`, `:instructor_name`, `:instructor_headshot_url` to the cast list in existing `changeset/2` and `update_changeset/2`.

**Step 4: Update ProgramMapper**

In `program_mapper.ex`, update `to_domain/1` to construct the Instructor VO from flat columns:

```elixir
alias KlassHero.ProgramCatalog.Domain.Models.Instructor

def to_domain(%ProgramSchema{} = schema) do
  instructor = build_instructor(schema)

  %Program{
    id: to_string(schema.id),
    provider_id: schema.provider_id && to_string(schema.provider_id),
    title: schema.title,
    description: schema.description,
    category: schema.category,
    schedule: schema.schedule,
    age_range: schema.age_range,
    price: schema.price,
    pricing_period: schema.pricing_period,
    spots_available: schema.spots_available || 0,
    icon_path: schema.icon_path,
    end_date: schema.end_date,
    lock_version: schema.lock_version,
    location: schema.location,
    cover_image_url: schema.cover_image_url,
    instructor: instructor,
    inserted_at: schema.inserted_at,
    updated_at: schema.updated_at
  }
end

# Trigger: instructor columns may all be nil (no instructor assigned)
# Why: instructor is optional — don't create a VO from nil data
# Outcome: nil when no instructor, Instructor VO when data present
defp build_instructor(%ProgramSchema{instructor_id: nil}), do: nil

defp build_instructor(%ProgramSchema{} = schema) do
  case Instructor.from_persistence(%{
         id: to_string(schema.instructor_id),
         name: schema.instructor_name,
         headshot_url: schema.instructor_headshot_url
       }) do
    {:ok, instructor} -> instructor
    {:error, _} -> nil
  end
end
```

Update `to_schema/1` to include new fields:

```elixir
def to_schema(%Program{} = program) do
  base = %{
    title: program.title,
    description: program.description,
    category: program.category,
    schedule: program.schedule,
    age_range: program.age_range,
    price: program.price,
    pricing_period: program.pricing_period,
    spots_available: program.spots_available,
    icon_path: program.icon_path,
    end_date: program.end_date,
    location: program.location,
    cover_image_url: program.cover_image_url
  }

  add_instructor_fields(base, program.instructor)
end

defp add_instructor_fields(attrs, nil) do
  Map.merge(attrs, %{instructor_id: nil, instructor_name: nil, instructor_headshot_url: nil})
end

defp add_instructor_fields(attrs, %Instructor{} = instructor) do
  Map.merge(attrs, %{
    instructor_id: instructor.id,
    instructor_name: instructor.name,
    instructor_headshot_url: instructor.headshot_url
  })
end
```

**Step 5: Add create/1 to ProgramRepository**

Add `@behaviour KlassHero.ProgramCatalog.Domain.Ports.ForCreatingPrograms` to existing behaviours.

```elixir
@impl true
def create(attrs) when is_map(attrs) do
  Logger.info("[ProgramRepository] Creating new program",
    provider_id: attrs[:provider_id],
    title: attrs[:title]
  )

  case %ProgramSchema{}
       |> ProgramSchema.create_changeset(attrs)
       |> Repo.insert() do
    {:ok, schema} ->
      program = ProgramMapper.to_domain(schema)

      Logger.info("[ProgramRepository] Successfully created program",
        program_id: program.id,
        title: program.title
      )

      {:ok, program}

    {:error, changeset} ->
      Logger.warning("[ProgramRepository] Program creation failed",
        errors: inspect(changeset.errors)
      )

      {:error, changeset}
  end
end
```

**Step 6: Verify compilation and run tests**

Run: `mix compile --warnings-as-errors && mix test`
Expected: compiles, all existing tests pass

**Step 7: Commit**

```bash
git add lib/klass_hero/program_catalog/domain/ports/for_creating_programs.ex \
  priv/repo/migrations/*_add_program_creation_fields.exs \
  lib/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema.ex \
  lib/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper.ex \
  lib/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_repository.ex
git commit -m "feat(program_catalog): add creation port, migration, schema, mapper, repository"
```

---

## Task 5: CreateProgram Use Case + Facade + Config

**Files:**
- Create: `lib/klass_hero/program_catalog/application/use_cases/create_program.ex`
- Create: `lib/klass_hero/program_catalog/adapters/driven/persistence/change_program.ex`
- Modify: `lib/klass_hero/program_catalog.ex` (public API)
- Modify: `config/config.exs:120-122` (add creation_repository key)
- Modify: `lib/klass_hero/application.ex` (register DomainEventBus)
- Test: `test/klass_hero/program_catalog/create_program_integration_test.exs`

**Reference:**
- Use case: `lib/klass_hero/identity/application/use_cases/staff_members/create_staff_member.ex`
- Config: `config/config.exs:120-122`
- Application: `lib/klass_hero/application.ex:45-58`

**Step 1: Write CreateProgram use case**

```elixir
# lib/klass_hero/program_catalog/application/use_cases/create_program.ex
defmodule KlassHero.ProgramCatalog.Application.UseCases.CreateProgram do
  @moduledoc """
  Use case for creating a new program.

  Orchestrates persistence and domain event publishing.
  Does NOT call Identity — the web layer is responsible for
  resolving instructor data before calling this use case.
  """

  alias KlassHero.ProgramCatalog.Domain.Events.ProgramEvents
  alias KlassHero.Shared.DomainEventBus

  @repository Application.compile_env!(:klass_hero, [:program_catalog, :creation_repository])

  def execute(attrs) when is_map(attrs) do
    attrs_with_id = Map.put_new(attrs, :id, Ecto.UUID.generate())

    with {:ok, program} <- @repository.create(attrs_with_id) do
      # Trigger: program successfully persisted
      # Why: downstream contexts may need to react (e.g., notifications)
      # Outcome: domain event dispatched to ProgramCatalog bus, then promoted to integration event
      event =
        ProgramEvents.program_created(program.id, %{
          provider_id: program.provider_id,
          title: program.title,
          category: program.category,
          instructor_id: program.instructor && program.instructor.id
        })

      DomainEventBus.dispatch(KlassHero.ProgramCatalog, event)

      {:ok, program}
    end
  end
end
```

**Step 2: Write ChangeProgram module (for LiveView forms)**

```elixir
# lib/klass_hero/program_catalog/adapters/driven/persistence/change_program.ex
defmodule KlassHero.ProgramCatalog.Adapters.Driven.Persistence.ChangeProgram do
  @moduledoc """
  Adapter for building program form changesets.

  Produces changesets for LiveView form tracking.
  """

  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema

  def new_changeset(attrs \\ %{}) do
    %ProgramSchema{} |> ProgramSchema.create_changeset(attrs)
  end
end
```

**Step 3: Update config**

In `config/config.exs`, change the program_catalog config block:

```elixir
config :klass_hero, :program_catalog,
  repository: KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepository,
  creation_repository: KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepository
```

**Step 4: Register ProgramCatalog DomainEventBus in application.ex**

In `lib/klass_hero/application.ex`, add to `domain_event_buses/0`:

```elixir
Supervisor.child_spec(
  {KlassHero.Shared.DomainEventBus,
   context: KlassHero.ProgramCatalog,
   handlers: [
     {:program_created,
      {KlassHero.ProgramCatalog.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
       :handle}, priority: 10}
   ]},
  id: :program_catalog_domain_event_bus
),
```

**Step 5: Add facade functions to ProgramCatalog**

In `lib/klass_hero/program_catalog.ex`, add:

```elixir
alias KlassHero.ProgramCatalog.Application.UseCases.CreateProgram
alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.ChangeProgram

# ============================================================================
# Program Creation
# ============================================================================

@doc """
Creates a new program.

## Parameters

- `attrs` - Map with: title, description, category, price, provider_id.
  Optional: location, cover_image_url, instructor_id, instructor_name, instructor_headshot_url.

## Returns

- `{:ok, Program.t()}` on success
- `{:error, changeset}` on validation failure
"""
@spec create_program(map()) :: {:ok, Program.t()} | {:error, term()}
def create_program(attrs) when is_map(attrs) do
  CreateProgram.execute(attrs)
end

@doc """
Returns an empty changeset for the program creation form.
"""
def new_program_changeset(attrs \\ %{}) do
  ChangeProgram.new_changeset(attrs)
end
```

**Step 6: Write integration test**

```elixir
# test/klass_hero/program_catalog/create_program_integration_test.exs
defmodule KlassHero.ProgramCatalog.CreateProgramIntegrationTest do
  use KlassHero.DataCase

  alias KlassHero.IdentityFixtures
  alias KlassHero.ProgramCatalog

  describe "create_program/1" do
    test "creates program with required fields" do
      provider = IdentityFixtures.provider_profile_fixture()

      assert {:ok, program} =
               ProgramCatalog.create_program(%{
                 provider_id: provider.id,
                 title: "Art Adventures",
                 description: "Creative art program for kids",
                 category: "arts",
                 price: Decimal.new("50.00")
               })

      assert program.title == "Art Adventures"
      assert program.category == "arts"
      assert program.instructor == nil
    end

    test "creates program with instructor" do
      provider = IdentityFixtures.provider_profile_fixture()
      staff = IdentityFixtures.staff_member_fixture(provider_id: provider.id)

      assert {:ok, program} =
               ProgramCatalog.create_program(%{
                 provider_id: provider.id,
                 title: "Soccer Camp",
                 description: "Learn to play soccer",
                 category: "sports",
                 price: Decimal.new("75.00"),
                 location: "Sports Park",
                 instructor_id: staff.id,
                 instructor_name: "#{staff.first_name} #{staff.last_name}",
                 instructor_headshot_url: staff.headshot_url
               })

      assert program.instructor != nil
      assert program.instructor.id == staff.id
      assert program.location == "Sports Park"
    end

    test "rejects missing required fields" do
      assert {:error, _changeset} =
               ProgramCatalog.create_program(%{title: "Incomplete"})
    end

    test "rejects invalid category" do
      provider = IdentityFixtures.provider_profile_fixture()

      assert {:error, _changeset} =
               ProgramCatalog.create_program(%{
                 provider_id: provider.id,
                 title: "Test",
                 description: "Test desc",
                 category: "invalid_category",
                 price: Decimal.new("10.00")
               })
    end
  end
end
```

**Step 7: Run tests**

Run: `mix test test/klass_hero/program_catalog/create_program_integration_test.exs`
Expected: all PASS

Run: `mix precommit`
Expected: compiles with zero warnings, all tests pass

**Step 8: Commit**

```bash
git add lib/klass_hero/program_catalog/application/use_cases/create_program.ex \
  lib/klass_hero/program_catalog/adapters/driven/persistence/change_program.ex \
  lib/klass_hero/program_catalog.ex \
  config/config.exs \
  lib/klass_hero/application.ex \
  test/klass_hero/program_catalog/create_program_integration_test.exs
git commit -m "feat(program_catalog): add CreateProgram use case, facade, event bus registration"
```

---

## Task 6: Update ProgramPresenter + Add Active Staff Filtering

**Files:**
- Modify: `lib/klass_hero_web/presenters/program_presenter.ex`
- Modify: `lib/klass_hero/identity.ex` (add list_active_staff_members)

**Reference:**
- Presenter: `program_presenter.ex:39-53`
- Identity facade: `lib/klass_hero/identity.ex` (list_staff_members)

**Step 1: Update ProgramPresenter**

Replace the placeholder `assigned_staff: nil` with real instructor data:

```elixir
def to_table_view(%Program{} = program) do
  %{
    id: program.id,
    name: program.title,
    category: humanize_category(program.category),
    price: Decimal.to_integer(program.price),
    assigned_staff: format_instructor(program.instructor),
    status: :active,
    enrolled: 0,
    capacity: program.spots_available
  }
end

defp format_instructor(nil), do: nil

defp format_instructor(instructor) do
  %{id: instructor.id, name: instructor.name, headshot_url: instructor.headshot_url}
end
```

**Step 2: Add list_active_staff_members to Identity facade**

In `lib/klass_hero/identity.ex`, add:

```elixir
@doc """
Lists active staff members for a provider.

Filters to only staff with `active: true`. Used by program creation
form to populate the instructor dropdown.
"""
def list_active_staff_members(provider_id) when is_binary(provider_id) do
  case @staff_repository.list_by_provider(provider_id) do
    {:ok, members} -> {:ok, Enum.filter(members, & &1.active)}
    error -> error
  end
end
```

**Step 3: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: zero warnings

**Step 4: Commit**

```bash
git add lib/klass_hero_web/presenters/program_presenter.ex lib/klass_hero/identity.ex
git commit -m "feat: update ProgramPresenter with instructor data, add active staff filter"
```

---

## Task 7: Program Form Component

**Files:**
- Modify: `lib/klass_hero_web/components/provider_components.ex`

**Reference:**
- `staff_member_form/1` in `provider_components.ex:513-700`
- Upload pattern in `dashboard_live.ex:798-810`

**Step 1: Add program_form/1 component**

Add to `provider_components.ex` (follow `staff_member_form/1` pattern):

```heex
attr :form, Phoenix.HTML.Form, required: true
attr :editing, :boolean, default: false
attr :uploads, :any, required: true
attr :instructor_options, :list, default: []

def program_form(assigns) do
  ~H"""
  <div class={["bg-white p-6 shadow-sm border border-hero-grey-200", Theme.rounded(:xl)]}>
    <div class="flex items-center justify-between mb-6">
      <h3 class="text-lg font-semibold text-hero-charcoal">
        <%= if @editing do %>
          {gettext("Edit Program")}
        <% else %>
          {gettext("New Program")}
        <% end %>
      </h3>
      <button type="button" phx-click="close_program_form" class="text-hero-grey-400 hover:text-hero-grey-600">
        <.icon name="hero-x-mark-mini" class="w-5 h-5" />
      </button>
    </div>

    <.form for={@form} id="program-form" phx-change="validate_program" phx-submit="save_program" class="space-y-4">
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <.input field={@form[:title]} type="text" label={gettext("Title")} placeholder={gettext("e.g., Art Adventures")} required />
        <.input
          field={@form[:category]}
          type="select"
          label={gettext("Category")}
          options={category_options()}
          prompt={gettext("Choose a category")}
          required
        />
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <.input field={@form[:price]} type="number" label={gettext("Price (EUR)")} placeholder="0.00" step="0.01" min="0" required />
        <.input field={@form[:location]} type="text" label={gettext("Location")} placeholder={gettext("e.g., Community Center, Main St")} />
      </div>

      <.input field={@form[:description]} type="textarea" label={gettext("Description")} placeholder={gettext("Describe your program...")} rows="3" required />

      <%!-- Cover Image Upload --%>
      <div>
        <label class="block text-sm font-semibold text-hero-charcoal mb-2">
          {gettext("Cover Image")}
        </label>
        <div
          id="program-cover-upload"
          class={["border-2 border-dashed border-hero-grey-300 p-4 text-center", Theme.rounded(:lg)]}
          phx-drop-target={@uploads.program_cover.ref}
        >
          <div :for={entry <- @uploads.program_cover.entries} class="mb-3">
            <.live_img_preview entry={entry} class="w-full max-w-xs mx-auto rounded-lg object-cover" />
            <p class="text-sm text-hero-grey-500 mt-1">{entry.client_name}</p>
            <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} phx-value-upload="program_cover" class="text-xs text-red-500 hover:text-red-700 mt-1">
              {gettext("Remove")}
            </button>
            <div :for={err <- upload_errors(@uploads.program_cover, entry)} class="text-xs text-red-500 mt-1">
              {upload_error_to_string(err)}
            </div>
          </div>

          <.live_file_input upload={@uploads.program_cover} class="hidden" />
          <label for={@uploads.program_cover.ref} class={[
            "inline-flex items-center gap-2 px-4 py-2 border border-hero-grey-300",
            "bg-white hover:bg-hero-grey-50 text-hero-charcoal text-sm font-medium cursor-pointer",
            Theme.rounded(:lg), Theme.transition(:normal)
          ]}>
            <.icon name="hero-photo-mini" class="w-4 h-4" />
            {gettext("Choose Image")}
          </label>
          <p class="text-xs text-hero-grey-400 mt-2">{gettext("JPG, PNG or WebP. Max 2MB.")}</p>
        </div>
      </div>

      <%!-- Assign Instructor --%>
      <.input
        field={@form[:instructor_id]}
        type="select"
        label={gettext("Assign Instructor")}
        options={@instructor_options}
        prompt={gettext("None (optional)")}
      />

      <div class="flex justify-end gap-3 pt-2">
        <button type="button" phx-click="close_program_form" class={[
          "px-4 py-2 border border-hero-grey-300 text-hero-charcoal",
          Theme.rounded(:lg), Theme.transition(:normal), "hover:bg-hero-grey-50"
        ]}>
          {gettext("Cancel")}
        </button>
        <button type="submit" id="save-program-btn" class={[
          "flex items-center gap-2 px-6 py-2.5 bg-hero-yellow hover:bg-hero-yellow-dark",
          "text-hero-charcoal font-semibold",
          Theme.rounded(:lg), Theme.transition(:normal)
        ]}>
          <.icon name="hero-check-mini" class="w-5 h-5" />
          {gettext("Save Program")}
        </button>
      </div>
    </.form>
  </div>
  """
end

defp category_options do
  KlassHero.ProgramCatalog.Domain.Services.ProgramCategories.program_categories()
  |> Enum.map(fn cat -> {String.capitalize(cat), cat} end)
end
```

**Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: zero warnings

**Step 3: Commit**

```bash
git add lib/klass_hero_web/components/provider_components.ex
git commit -m "feat(web): add program_form component for provider dashboard"
```

---

## Task 8: Dashboard LiveView — Program CRUD Events

**Files:**
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex`

**Reference:**
- Staff CRUD events: `dashboard_live.ex:169-307`
- Upload helper: `dashboard_live.ex:798-810`
- Mount: `dashboard_live.ex:27-93`

**Step 1: Update mount**

Add `allow_upload(:program_cover, ...)` alongside existing uploads:

```elixir
|> allow_upload(:program_cover,
  accept: ~w(.jpg .jpeg .png .webp),
  max_entries: 1,
  max_file_size: 2_000_000
)
```

Add assigns:

```elixir
|> assign(show_program_form: false)
|> assign(program_form: to_form(ProgramCatalog.new_program_changeset()))
|> assign(instructor_options: build_instructor_options(provider_profile.id))
```

**Step 2: Add instructor_options builder**

```elixir
defp build_instructor_options(provider_id) do
  case Identity.list_active_staff_members(provider_id) do
    {:ok, members} ->
      Enum.map(members, fn m ->
        {KlassHero.Identity.Domain.Models.StaffMember.full_name(m), m.id}
      end)

    {:error, _} ->
      []
  end
end
```

**Step 3: Add handle_event clauses for program CRUD**

```elixir
# ============================================================================
# Program Creation Events
# ============================================================================

@impl true
def handle_event("add_program", _params, socket) do
  {:noreply,
   socket
   |> assign(show_program_form: true)
   |> assign(program_form: to_form(ProgramCatalog.new_program_changeset()))
   |> assign(instructor_options: build_instructor_options(socket.assigns.current_scope.provider.id))}
end

@impl true
def handle_event("close_program_form", _params, socket) do
  {:noreply, assign(socket, show_program_form: false)}
end

@impl true
def handle_event("validate_program", %{"program_schema" => params}, socket) do
  changeset =
    ProgramCatalog.new_program_changeset(params)
    |> Map.put(:action, :validate)

  {:noreply, assign(socket, program_form: to_form(changeset))}
end

@impl true
def handle_event("save_program", %{"program_schema" => params}, socket) do
  provider = socket.assigns.current_scope.provider

  # Trigger: cover image upload may or may not be present
  # Why: program can be saved without a cover image
  # Outcome: include cover_image_url in attrs if upload succeeded
  cover_result = upload_program_cover(socket, provider.id)

  attrs =
    %{
      provider_id: provider.id,
      title: params["title"],
      description: params["description"],
      category: params["category"],
      price: params["price"],
      location: presence(params["location"])
    }
    |> maybe_add_cover_image(cover_result)
    |> maybe_add_instructor(params["instructor_id"], socket)

  case ProgramCatalog.create_program(attrs) do
    {:ok, program} ->
      view = ProgramPresenter.to_table_view(program)

      {:noreply,
       socket
       |> stream_insert(:programs, view)
       |> assign(
         show_program_form: false,
         programs_count: socket.assigns.programs_count + 1
       )
       |> clear_flash(:error)
       |> put_flash(:info, gettext("Program created successfully."))}

    {:error, changeset} ->
      {:noreply,
       socket
       |> assign(program_form: to_form(Map.put(changeset, :action, :validate)))
       |> put_flash(:error, gettext("Please fix the errors below."))}
  end
end
```

**Step 4: Add helper functions**

```elixir
defp upload_program_cover(socket, provider_id) do
  case consume_uploaded_entries(socket, :program_cover, fn %{path: path}, entry ->
         file_binary = File.read!(path)
         safe_name = String.replace(entry.client_name, ~r/[^a-zA-Z0-9._-]/, "_")
         storage_path = "program_covers/providers/#{provider_id}/#{safe_name}"

         Storage.upload(:public, storage_path, file_binary, content_type: entry.client_type)
       end) do
    [{:ok, url}] -> {:ok, url}
    [] -> :no_upload
    _other -> :upload_error
  end
end

defp maybe_add_cover_image(attrs, {:ok, url}), do: Map.put(attrs, :cover_image_url, url)
defp maybe_add_cover_image(attrs, _), do: attrs

# Trigger: instructor_id may be "" (none selected) or a valid UUID
# Why: instructor is optional; when selected, we resolve display data from Identity
# Outcome: attrs enriched with instructor_id/name/headshot_url, or unchanged if none
defp maybe_add_instructor(attrs, nil, _socket), do: attrs
defp maybe_add_instructor(attrs, "", _socket), do: attrs

defp maybe_add_instructor(attrs, instructor_id, socket) do
  case Identity.get_staff_member(instructor_id) do
    {:ok, staff} ->
      # Trigger: staff member found in Identity
      # Why: ProgramCatalog stores denormalized instructor display data (ACL)
      # Outcome: attrs include flat instructor columns for persistence
      attrs
      |> Map.put(:instructor_id, staff.id)
      |> Map.put(:instructor_name, KlassHero.Identity.Domain.Models.StaffMember.full_name(staff))
      |> Map.put(:instructor_headshot_url, staff.headshot_url)

    {:error, :not_found} ->
      Logger.warning("Instructor not found during program creation",
        instructor_id: instructor_id,
        provider_id: socket.assigns.current_scope.provider.id
      )

      attrs
  end
end
```

**Step 5: Update programs_section template**

Add the program form panel above the programs table (same as team_section pattern with staff_form):

```heex
defp programs_section(assigns) do
  ~H"""
  <div class="space-y-6">
    <%= if @show_program_form do %>
      <.program_form
        form={@program_form}
        uploads={@uploads}
        instructor_options={@instructor_options}
      />
    <% end %>

    <.programs_table
      programs={@programs}
      staff_options={@staff_options}
      search_query={@search_query}
      selected_staff={@selected_staff}
    />
  </div>
  """
end
```

**Step 6: Update the "New Program" button**

In `provider_dashboard_header`, wire the existing disabled button to `phx-click="add_program"` (it already has the verification gating).

**Step 7: Update render to pass new assigns to programs_section**

```heex
<% :programs -> %>
  <.programs_section
    programs={@streams.programs}
    staff_options={@staff_options}
    search_query={@search_query}
    selected_staff={@selected_staff}
    show_program_form={@show_program_form}
    program_form={@program_form}
    uploads={@uploads}
    instructor_options={@instructor_options}
  />
```

**Step 8: Run precommit**

Run: `mix precommit`
Expected: compiles, formats, all tests pass

**Step 9: Commit**

```bash
git add lib/klass_hero_web/live/provider/dashboard_live.ex
git commit -m "feat(web): wire program creation into provider dashboard"
```

---

## Task 9: LiveView Tests

**Files:**
- Create: `test/klass_hero_web/live/provider/dashboard_program_creation_test.exs`

**Reference:** `test/klass_hero_web/live/provider/dashboard_team_test.exs`

**Step 1: Write tests**

```elixir
# test/klass_hero_web/live/provider/dashboard_program_creation_test.exs
defmodule KlassHeroWeb.Provider.DashboardProgramCreationTest do
  use KlassHeroWeb.ConnCase

  import Phoenix.LiveViewTest

  alias KlassHero.IdentityFixtures

  setup :register_and_log_in_user

  setup %{user: user} do
    provider = IdentityFixtures.provider_profile_fixture(%{user_id: user.id, verified: true})
    %{provider: provider}
  end

  describe "program creation form" do
    test "shows program form when add_program clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#add-program-btn") |> render_click()

      assert has_element?(view, "#program-form")
    end

    test "validates program form on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#add-program-btn") |> render_click()

      view
      |> form("#program-form", %{program_schema: %{title: ""}})
      |> render_change()

      # Form should show validation state
      assert has_element?(view, "#program-form")
    end

    test "creates program with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#add-program-btn") |> render_click()

      view
      |> form("#program-form", %{
        program_schema: %{
          title: "Art Adventures",
          description: "Creative art program for kids",
          category: "arts",
          price: "50.00"
        }
      })
      |> render_submit()

      # Form should close and program should appear
      refute has_element?(view, "#program-form")
    end

    test "creates program with instructor assigned", %{conn: conn, provider: provider} do
      staff = IdentityFixtures.staff_member_fixture(provider_id: provider.id, first_name: "Mike", last_name: "J")

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#add-program-btn") |> render_click()

      view
      |> form("#program-form", %{
        program_schema: %{
          title: "Soccer Camp",
          description: "Learn to play soccer",
          category: "sports",
          price: "75.00",
          location: "Sports Park",
          instructor_id: staff.id
        }
      })
      |> render_submit()

      refute has_element?(view, "#program-form")
    end

    test "closes form on cancel", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#add-program-btn") |> render_click()
      assert has_element?(view, "#program-form")

      view |> element("button[phx-click=close_program_form]") |> render_click()
      refute has_element?(view, "#program-form")
    end
  end
end
```

**Step 2: Run tests**

Run: `mix test test/klass_hero_web/live/provider/dashboard_program_creation_test.exs`
Expected: all PASS

**Step 3: Run full suite**

Run: `mix precommit`
Expected: all pass

**Step 4: Commit**

```bash
git add test/klass_hero_web/live/provider/dashboard_program_creation_test.exs
git commit -m "test: add LiveView tests for program creation flow"
```

---

## Verification Checklist

After all tasks complete:

1. `mix precommit` — compiles with `--warnings-as-errors`, formats, all tests pass
2. Navigate to `/provider/dashboard/programs` — see programs table
3. Click "New Program" — form panel opens inline
4. Fill form (title, category, price, description) and submit — program appears in table
5. Assign instructor from dropdown — program shows instructor in table
6. Upload cover image — file accepted and stored
7. Cancel button closes form without saving
8. Validation errors display on invalid input
