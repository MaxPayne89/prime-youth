# ProgramCatalog Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the Program aggregate root enforce business invariants, so use cases route through the domain model before persistence.

**Architecture:** Aggregate factory pattern. `Program.create/1` validates business rules and builds the struct. `Program.apply_changes/2` does the same for mutations. Ports become type-safe (`Program.t()` in, `Program.t()` out). Ecto changesets remain as defense-in-depth at the persistence boundary.

**Tech Stack:** Elixir, Ecto, ExUnit

**Design doc:** `docs/plans/2026-02-14-program-catalog-redesign-design.md`

---

### Task 1: Program aggregate — `create/1` factory (tests)

**Files:**
- Modify: `test/klass_hero/program_catalog/domain/models/program_test.exs`

**Step 1: Write failing tests for `Program.create/1`**

Add a new `describe "create/1"` block to the existing test file. Tests cover:

```elixir
describe "create/1" do
  test "creates program from valid attrs" do
    attrs = %{
      title: "Summer Soccer Camp",
      description: "Fun soccer activities for kids",
      category: "sports",
      price: Decimal.new("150.00"),
      provider_id: "660e8400-e29b-41d4-a716-446655440001",
      spots_available: 20
    }

    assert {:ok, program} = Program.create(attrs)
    assert program.title == "Summer Soccer Camp"
    assert program.category == "sports"
    assert program.id == nil
    assert program.spots_available == 20
  end

  test "creates program with optional fields" do
    attrs = %{
      title: "Art Adventures",
      description: "Creative art program",
      category: "arts",
      price: Decimal.new("50.00"),
      provider_id: "660e8400-e29b-41d4-a716-446655440001",
      schedule: "Mon-Fri 3-5pm",
      age_range: "6-10 years",
      pricing_period: "per week",
      location: "Community Center"
    }

    assert {:ok, program} = Program.create(attrs)
    assert program.schedule == "Mon-Fri 3-5pm"
    assert program.location == "Community Center"
  end

  test "creates program with valid instructor data" do
    attrs = %{
      title: "Coached Program",
      description: "Has instructor",
      category: "sports",
      price: Decimal.new("100.00"),
      provider_id: "660e8400-e29b-41d4-a716-446655440001",
      instructor: %{id: "abc-123", name: "Jane Coach", headshot_url: "https://example.com/photo.jpg"}
    }

    assert {:ok, program} = Program.create(attrs)
    assert %Instructor{} = program.instructor
    assert program.instructor.name == "Jane Coach"
  end

  test "creates program without instructor" do
    attrs = %{
      title: "No Coach",
      description: "Self-directed program",
      category: "arts",
      price: Decimal.new("50.00"),
      provider_id: "660e8400-e29b-41d4-a716-446655440001"
    }

    assert {:ok, program} = Program.create(attrs)
    assert program.instructor == nil
  end

  test "defaults spots_available to 0" do
    attrs = %{
      title: "Default Spots",
      description: "No spots specified",
      category: "arts",
      price: Decimal.new("50.00"),
      provider_id: "660e8400-e29b-41d4-a716-446655440001"
    }

    assert {:ok, program} = Program.create(attrs)
    assert program.spots_available == 0
  end

  test "rejects empty title" do
    attrs = %{
      title: "",
      description: "Valid description",
      category: "sports",
      price: Decimal.new("100.00"),
      provider_id: "660e8400-e29b-41d4-a716-446655440001"
    }

    assert {:error, errors} = Program.create(attrs)
    assert is_list(errors)
    assert Enum.any?(errors, &String.contains?(&1, "title"))
  end

  test "rejects whitespace-only title" do
    attrs = %{
      title: "   ",
      description: "Valid",
      category: "sports",
      price: Decimal.new("100.00"),
      provider_id: "660e8400-e29b-41d4-a716-446655440001"
    }

    assert {:error, errors} = Program.create(attrs)
    assert Enum.any?(errors, &String.contains?(&1, "title"))
  end

  test "rejects missing title" do
    attrs = %{
      description: "Valid",
      category: "sports",
      price: Decimal.new("100.00"),
      provider_id: "660e8400-e29b-41d4-a716-446655440001"
    }

    assert {:error, errors} = Program.create(attrs)
    assert Enum.any?(errors, &String.contains?(&1, "title"))
  end

  test "rejects empty description" do
    attrs = %{
      title: "Valid Title",
      description: "",
      category: "sports",
      price: Decimal.new("100.00"),
      provider_id: "660e8400-e29b-41d4-a716-446655440001"
    }

    assert {:error, errors} = Program.create(attrs)
    assert Enum.any?(errors, &String.contains?(&1, "description"))
  end

  test "rejects invalid category" do
    attrs = %{
      title: "Valid Title",
      description: "Valid description",
      category: "invalid_category",
      price: Decimal.new("100.00"),
      provider_id: "660e8400-e29b-41d4-a716-446655440001"
    }

    assert {:error, errors} = Program.create(attrs)
    assert Enum.any?(errors, &String.contains?(&1, "category"))
  end

  test "rejects missing category" do
    attrs = %{
      title: "Valid Title",
      description: "Valid description",
      price: Decimal.new("100.00"),
      provider_id: "660e8400-e29b-41d4-a716-446655440001"
    }

    assert {:error, errors} = Program.create(attrs)
    assert Enum.any?(errors, &String.contains?(&1, "category"))
  end

  test "rejects negative price" do
    attrs = %{
      title: "Valid Title",
      description: "Valid description",
      category: "sports",
      price: Decimal.new("-10.00"),
      provider_id: "660e8400-e29b-41d4-a716-446655440001"
    }

    assert {:error, errors} = Program.create(attrs)
    assert Enum.any?(errors, &String.contains?(&1, "price"))
  end

  test "rejects missing provider_id" do
    attrs = %{
      title: "Valid Title",
      description: "Valid description",
      category: "sports",
      price: Decimal.new("100.00")
    }

    assert {:error, errors} = Program.create(attrs)
    assert Enum.any?(errors, &String.contains?(&1, "provider"))
  end

  test "rejects negative spots_available" do
    attrs = %{
      title: "Valid",
      description: "Valid",
      category: "sports",
      price: Decimal.new("100.00"),
      provider_id: "660e8400-e29b-41d4-a716-446655440001",
      spots_available: -1
    }

    assert {:error, errors} = Program.create(attrs)
    assert Enum.any?(errors, &String.contains?(&1, "spots"))
  end

  test "rejects invalid instructor data" do
    attrs = %{
      title: "Valid",
      description: "Valid",
      category: "sports",
      price: Decimal.new("100.00"),
      provider_id: "660e8400-e29b-41d4-a716-446655440001",
      instructor: %{id: "", name: "Jane"}
    }

    assert {:error, errors} = Program.create(attrs)
    assert Enum.any?(errors, &String.contains?(&1, "nstructor"))
  end

  test "accepts price of zero (free programs)" do
    attrs = %{
      title: "Free Event",
      description: "A free community event",
      category: "education",
      price: Decimal.new("0"),
      provider_id: "660e8400-e29b-41d4-a716-446655440001"
    }

    assert {:ok, program} = Program.create(attrs)
    assert Program.free?(program)
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/program_catalog/domain/models/program_test.exs --max-failures 1`
Expected: FAIL — `Program.create/1` undefined

**Step 3: Commit the failing tests**

```bash
git add test/klass_hero/program_catalog/domain/models/program_test.exs
git commit -m "test: add failing tests for Program.create/1 factory"
```

---

### Task 2: Program aggregate — `create/1` implementation

**Files:**
- Modify: `lib/klass_hero/program_catalog/domain/models/program.ex`

**Step 1: Remove `:id` from `@enforce_keys`**

Change line 11:
```elixir
# Before
@enforce_keys [:id, :title, :description, :category, :price]

# After
@enforce_keys [:title, :description, :category, :price]
```

**Step 2: Add `create/1` factory and private helpers**

Add after the existing `valid?/1` function:

```elixir
@doc """
Creates a new Program from untrusted input, validating business invariants.

Unlike `new/1` (which assumes trusted data from persistence), this function
validates all business rules before constructing the struct.

Returns `{:ok, Program.t()}` with `id: nil` — the persistence layer assigns the ID.
"""
@spec create(map()) :: {:ok, t()} | {:error, [String.t()]}
def create(attrs) when is_map(attrs) do
  with {:ok, instructor} <- build_instructor_from_attrs(attrs),
       {:ok, base} <- build_base(attrs, instructor) do
    {:ok, base}
  end
end

defp build_instructor_from_attrs(%{instructor: instructor_attrs}) when is_map(instructor_attrs) do
  case Instructor.new(instructor_attrs) do
    {:ok, instructor} -> {:ok, instructor}
    {:error, reasons} -> {:error, Enum.map(reasons, &"Instructor: #{&1}")}
  end
end

defp build_instructor_from_attrs(_), do: {:ok, nil}

defp build_base(attrs, instructor) do
  errors = validate_creation_invariants(attrs)

  if errors == [] do
    {:ok,
     %__MODULE__{
       title: attrs[:title],
       description: attrs[:description],
       category: attrs[:category],
       price: attrs[:price],
       provider_id: attrs[:provider_id],
       schedule: attrs[:schedule],
       age_range: attrs[:age_range],
       pricing_period: attrs[:pricing_period],
       spots_available: attrs[:spots_available] || 0,
       icon_path: attrs[:icon_path],
       end_date: attrs[:end_date],
       location: attrs[:location],
       cover_image_url: attrs[:cover_image_url],
       instructor: instructor
     }}
  else
    {:error, errors}
  end
end

defp validate_creation_invariants(attrs) do
  []
  |> validate_required_string(attrs, :title, "Title is required")
  |> validate_required_string(attrs, :description, "Description is required")
  |> validate_category(attrs[:category])
  |> validate_price(attrs[:price])
  |> validate_spots(attrs[:spots_available])
  |> validate_provider_id(attrs[:provider_id])
end

defp validate_required_string(errors, attrs, key, message) do
  value = attrs[key]

  if is_binary(value) and String.trim(value) != "" do
    errors
  else
    [message | errors]
  end
end

defp validate_category(errors \\ [], category)

defp validate_category(errors, category) when is_binary(category) do
  if ProgramCategories.valid_program_category?(category) do
    errors
  else
    ["Category is invalid" | errors]
  end
end

defp validate_category(errors, _), do: ["Category is required" | errors]

defp validate_price(errors \\ [], price)

defp validate_price(errors, %Decimal{} = price) do
  if Decimal.compare(price, Decimal.new(0)) != :lt do
    errors
  else
    ["Price must be greater than or equal to 0" | errors]
  end
end

defp validate_price(errors, _), do: ["Price is required" | errors]

defp validate_spots(errors \\ [], spots)
defp validate_spots(errors, nil), do: errors
defp validate_spots(errors, spots) when is_integer(spots) and spots >= 0, do: errors
defp validate_spots(errors, _), do: ["Spots available must be greater than or equal to 0" | errors]

defp validate_provider_id(errors \\ [], provider_id)

defp validate_provider_id(errors, id) when is_binary(id) and byte_size(id) > 0, do: errors
defp validate_provider_id(errors, _), do: ["Provider ID is required" | errors]
```

Note: `validate_category/2` and others use the multi-head `defp` pattern with a default first arg. This avoids nesting `if` blocks.

**Step 3: Run the create/1 tests**

Run: `mix test test/klass_hero/program_catalog/domain/models/program_test.exs`
Expected: All tests PASS (new create/1 tests + existing tests still green)

**Step 4: Commit**

```bash
git add lib/klass_hero/program_catalog/domain/models/program.ex
git commit -m "feat: add Program.create/1 factory with business invariant validation"
```

---

### Task 3: Program aggregate — `apply_changes/2` (tests + implementation)

**Files:**
- Modify: `test/klass_hero/program_catalog/domain/models/program_test.exs`
- Modify: `lib/klass_hero/program_catalog/domain/models/program.ex`

**Step 1: Write failing tests for `apply_changes/2`**

```elixir
describe "apply_changes/2" do
  defp existing_program do
    %Program{
      id: "550e8400-e29b-41d4-a716-446655440000",
      title: "Original Title",
      description: "Original description",
      category: "sports",
      price: Decimal.new("150.00"),
      provider_id: "660e8400-e29b-41d4-a716-446655440001",
      spots_available: 20,
      lock_version: 1
    }
  end

  test "updates title" do
    program = existing_program()
    assert {:ok, updated} = Program.apply_changes(program, %{title: "New Title"})
    assert updated.title == "New Title"
    assert updated.description == "Original description"
  end

  test "updates multiple fields" do
    program = existing_program()

    assert {:ok, updated} =
             Program.apply_changes(program, %{
               title: "Updated",
               price: Decimal.new("200.00"),
               spots_available: 15
             })

    assert updated.title == "Updated"
    assert updated.price == Decimal.new("200.00")
    assert updated.spots_available == 15
  end

  test "preserves fields not in changes" do
    program = existing_program()
    assert {:ok, updated} = Program.apply_changes(program, %{title: "New"})
    assert updated.category == "sports"
    assert updated.provider_id == "660e8400-e29b-41d4-a716-446655440001"
    assert updated.lock_version == 1
  end

  test "adds instructor to program without one" do
    program = existing_program()

    assert {:ok, updated} =
             Program.apply_changes(program, %{
               instructor: %{id: "abc-123", name: "Jane Coach"}
             })

    assert %Instructor{} = updated.instructor
    assert updated.instructor.name == "Jane Coach"
  end

  test "removes instructor when set to nil" do
    {:ok, instructor} = Instructor.new(%{id: "abc-123", name: "Jane"})
    program = %{existing_program() | instructor: instructor}

    assert {:ok, updated} = Program.apply_changes(program, %{instructor: nil})
    assert updated.instructor == nil
  end

  test "rejects invalid changes (empty title)" do
    program = existing_program()
    assert {:error, errors} = Program.apply_changes(program, %{title: ""})
    assert Enum.any?(errors, &String.contains?(&1, "title"))
  end

  test "rejects invalid changes (negative price)" do
    program = existing_program()
    assert {:error, errors} = Program.apply_changes(program, %{price: Decimal.new("-5.00")})
    assert Enum.any?(errors, &String.contains?(&1, "price"))
  end

  test "rejects invalid category change" do
    program = existing_program()
    assert {:error, errors} = Program.apply_changes(program, %{category: "invalid"})
    assert Enum.any?(errors, &String.contains?(&1, "category"))
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/program_catalog/domain/models/program_test.exs --max-failures 1`
Expected: FAIL — `Program.apply_changes/2` undefined

**Step 3: Implement `apply_changes/2`**

Add to `program.ex` after `create/1`:

```elixir
@doc """
Applies changes to an existing Program, re-validating all business invariants.

Takes the current program and a map of changes. Only keys present in the
changes map are updated; all others are preserved.
"""
@spec apply_changes(t(), map()) :: {:ok, t()} | {:error, [String.t()]}
def apply_changes(%__MODULE__{} = program, changes) when is_map(changes) do
  with {:ok, instructor} <- resolve_instructor(program, changes) do
    updated = merge_fields(program, changes, instructor)
    errors = validate_mutation_invariants(updated)

    if errors == [] do
      {:ok, updated}
    else
      {:error, errors}
    end
  end
end

defp resolve_instructor(program, %{instructor: nil}), do: {:ok, nil}

defp resolve_instructor(_program, %{instructor: attrs}) when is_map(attrs) do
  case Instructor.new(attrs) do
    {:ok, instructor} -> {:ok, instructor}
    {:error, reasons} -> {:error, Enum.map(reasons, &"Instructor: #{&1}")}
  end
end

defp resolve_instructor(program, _changes), do: {:ok, program.instructor}

@updatable_fields ~w(title description category price spots_available schedule
                     age_range pricing_period icon_path end_date location cover_image_url)a

defp merge_fields(program, changes, instructor) do
  merged =
    Enum.reduce(@updatable_fields, program, fn field, acc ->
      if Map.has_key?(changes, field) do
        Map.put(acc, field, Map.get(changes, field))
      else
        acc
      end
    end)

  %{merged | instructor: instructor}
end

defp validate_mutation_invariants(program) do
  []
  |> then(fn errors ->
    if is_binary(program.title) and String.trim(program.title) != "",
      do: errors,
      else: ["Title is required" | errors]
  end)
  |> then(fn errors ->
    if is_binary(program.description) and String.trim(program.description) != "",
      do: errors,
      else: ["Description is required" | errors]
  end)
  |> validate_category(program.category)
  |> validate_price(program.price)
  |> validate_spots(program.spots_available)
end
```

**Step 4: Run tests**

Run: `mix test test/klass_hero/program_catalog/domain/models/program_test.exs`
Expected: All PASS

**Step 5: Commit**

```bash
git add lib/klass_hero/program_catalog/domain/models/program.ex test/klass_hero/program_catalog/domain/models/program_test.exs
git commit -m "feat: add Program.apply_changes/2 for aggregate mutations"
```

---

### Task 4: Update existing Program tests for `:id` no longer enforced

**Files:**
- Modify: `test/klass_hero/program_catalog/domain/models/program_test.exs`

**Step 1: Verify existing tests still pass after `:id` removal from enforce_keys**

Run: `mix test test/klass_hero/program_catalog/domain/models/program_test.exs`
Expected: All PASS — existing tests provide `:id` so `struct!` still works

Note: If any tests constructed `%Program{}` directly without `:id` and expected failure, they would need updating. Based on the current test file, all existing tests provide `:id`, so no changes needed.

**Step 2: Verify the full test suite compiles**

Run: `mix test --max-failures 3`
Expected: PASS — nothing else depends on `:id` being in `@enforce_keys`

---

### Task 5: Port contracts — make type-safe

**Files:**
- Modify: `lib/klass_hero/program_catalog/domain/ports/for_creating_programs.ex`
- Modify: `lib/klass_hero/program_catalog/domain/ports/for_updating_programs.ex`

**Step 1: Update ForCreatingPrograms callback**

```elixir
# Change from:
@callback create(attrs :: map()) ::
            {:ok, Program.t()} | {:error, Ecto.Changeset.t()}

# To:
@callback create(program :: Program.t()) ::
            {:ok, Program.t()} | {:error, Ecto.Changeset.t()}
```

**Step 2: Update ForUpdatingPrograms callback**

```elixir
# Change from:
@callback update(program :: term()) ::
            {:ok, term()} | {:error, :stale_data | :not_found | term()}

# To:
@callback update(program :: Program.t()) ::
            {:ok, Program.t()} | {:error, :stale_data | :not_found | Ecto.Changeset.t()}
```

Add `alias KlassHero.ProgramCatalog.Domain.Models.Program` to the ForUpdatingPrograms module.

**Step 3: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: PASS — the repository already pattern-matches on `%Program{}` for update, and create will be updated next.

**Step 4: Commit**

```bash
git add lib/klass_hero/program_catalog/domain/ports/for_creating_programs.ex lib/klass_hero/program_catalog/domain/ports/for_updating_programs.ex
git commit -m "refactor: make port contracts type-safe with Program.t()"
```

---

### Task 6: Mapper — extend `to_schema/1` to include `provider_id`

**Files:**
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper.ex`
- Modify: `test/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper_test.exs`

**Step 1: Add test for `provider_id` in `to_schema/1`**

Add to the existing mapper test file a new `describe "to_schema/1"` block:

```elixir
describe "to_schema/1" do
  test "includes provider_id in output" do
    program = %Program{
      id: "550e8400-e29b-41d4-a716-446655440000",
      title: "Test",
      description: "Desc",
      category: "arts",
      price: Decimal.new("50.00"),
      provider_id: "660e8400-e29b-41d4-a716-446655440001",
      spots_available: 10
    }

    attrs = ProgramMapper.to_schema(program)
    assert attrs.provider_id == "660e8400-e29b-41d4-a716-446655440001"
  end

  test "includes all fields needed for create_changeset" do
    {:ok, instructor} = Instructor.new(%{id: "abc", name: "Jane"})

    program = %Program{
      id: nil,
      title: "Test",
      description: "Desc",
      category: "arts",
      price: Decimal.new("50.00"),
      provider_id: "660e8400-e29b-41d4-a716-446655440001",
      spots_available: 10,
      location: "Park",
      cover_image_url: "https://example.com/img.jpg",
      instructor: instructor
    }

    attrs = ProgramMapper.to_schema(program)
    assert attrs.provider_id == "660e8400-e29b-41d4-a716-446655440001"
    assert attrs.location == "Park"
    assert attrs.cover_image_url == "https://example.com/img.jpg"
    assert attrs.instructor_id == "abc"
    assert attrs.instructor_name == "Jane"
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper_test.exs`
Expected: FAIL — `provider_id` not in output

**Step 3: Add `provider_id` to `to_schema/1`**

In `program_mapper.ex`, modify the `to_schema/1` function's base map to include `provider_id`:

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
    cover_image_url: program.cover_image_url,
    provider_id: program.provider_id
  }

  add_instructor_fields(base, program.instructor)
end
```

**Step 4: Run tests**

Run: `mix test test/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper_test.exs`
Expected: All PASS

**Step 5: Commit**

```bash
git add lib/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper.ex test/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper_test.exs
git commit -m "feat: extend ProgramMapper.to_schema/1 to include provider_id"
```

---

### Task 7: Repository — update `create/1` to accept `Program.t()`

**Files:**
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_repository.ex`

**Step 1: Update `create/1` to accept `%Program{}`**

Replace the current `create/1` function:

```elixir
@impl true
def create(%Program{} = program) do
  attrs = ProgramMapper.to_schema(program)

  Logger.info("[ProgramRepository] Creating new program",
    provider_id: program.provider_id,
    title: program.title
  )

  %ProgramSchema{}
  |> ProgramSchema.create_changeset(attrs)
  |> Repo.insert()
  |> case do
    {:ok, schema} ->
      persisted = ProgramMapper.to_domain(schema)

      Logger.info("[ProgramRepository] Successfully created program",
        program_id: persisted.id,
        title: persisted.title
      )

      {:ok, persisted}

    {:error, changeset} ->
      Logger.warning("[ProgramRepository] Program creation failed",
        errors: inspect(changeset.errors)
      )

      {:error, changeset}
  end
end
```

**Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: PASS

**Step 3: Commit**

```bash
git add lib/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_repository.ex
git commit -m "refactor: repository create/1 accepts Program.t() instead of raw map"
```

---

### Task 8: CreateProgram use case — orchestrate through aggregate

**Files:**
- Modify: `lib/klass_hero/program_catalog/application/use_cases/create_program.ex`

**Step 1: Update `execute/1` to use `Program.create/1` first**

```elixir
defmodule KlassHero.ProgramCatalog.Application.UseCases.CreateProgram do
  @moduledoc """
  Use case for creating a new program.

  Orchestrates domain validation and persistence:
  1. Builds and validates the Program aggregate via Program.create/1
  2. Persists via the repository adapter
  3. Dispatches domain events on success
  """

  alias KlassHero.ProgramCatalog.Domain.Events.ProgramEvents
  alias KlassHero.ProgramCatalog.Domain.Models.Program
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @repository Application.compile_env!(:klass_hero, [:program_catalog, :repository])

  def execute(attrs) when is_map(attrs) do
    with {:ok, program} <- Program.create(attrs),
         {:ok, persisted} <- @repository.create(program) do
      dispatch_event(persisted)
      {:ok, persisted}
    end
  end

  defp dispatch_event(program) do
    event =
      ProgramEvents.program_created(program.id, %{
        provider_id: program.provider_id,
        title: program.title,
        category: program.category,
        instructor_id: program.instructor && program.instructor.id
      })

    case DomainEventBus.dispatch(KlassHero.ProgramCatalog, event) do
      :ok ->
        :ok

      {:error, failures} ->
        Logger.warning("[CreateProgram] Event dispatch had failures",
          program_id: program.id,
          errors: inspect(failures)
        )
    end
  end
end
```

**Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: PASS

**Step 3: Commit**

```bash
git add lib/klass_hero/program_catalog/application/use_cases/create_program.ex
git commit -m "refactor: CreateProgram use case orchestrates through aggregate"
```

---

### Task 9: Update integration tests for new error types

**Files:**
- Modify: `test/klass_hero/program_catalog/create_program_integration_test.exs`

**Step 1: Update tests that assert on changeset errors**

The `create_program` now returns `{:error, [String.t()]}` for domain validation failures (missing fields, invalid category, negative price) instead of `{:error, changeset}`. Tests asserting on changeset structure need updating:

```elixir
# Update "rejects missing required fields" test:
test "rejects missing required fields" do
  assert {:error, errors} =
           ProgramCatalog.create_program(%{title: "Incomplete"})

  # Trigger: domain model catches missing fields before hitting Ecto
  # Why: Program.create/1 validates invariants first
  # Outcome: errors is a list of strings, not a changeset
  assert is_list(errors)
  assert Enum.any?(errors, &String.contains?(&1, "description"))
  assert Enum.any?(errors, &String.contains?(&1, "category"))
  assert Enum.any?(errors, &String.contains?(&1, "price"))
  assert Enum.any?(errors, &String.contains?(&1, "rovider"))
end

# Update "rejects negative price" test:
test "rejects negative price" do
  provider = ProviderFixtures.provider_profile_fixture()

  assert {:error, errors} =
           ProgramCatalog.create_program(%{
             provider_id: provider.id,
             title: "Bad Price Program",
             description: "Has negative price",
             category: "arts",
             price: Decimal.new("-5.00")
           })

  assert is_list(errors)
  assert Enum.any?(errors, &String.contains?(&1, "rice"))
end

# Update "rejects invalid category" test:
test "rejects invalid category" do
  provider = ProviderFixtures.provider_profile_fixture()

  assert {:error, errors} =
           ProgramCatalog.create_program(%{
             provider_id: provider.id,
             title: "Test",
             description: "Test desc",
             category: "invalid_category",
             price: Decimal.new("10.00")
           })

  assert is_list(errors)
  assert Enum.any?(errors, &String.contains?(&1, "ategory"))
end
```

**Step 2: Run integration tests**

Run: `mix test test/klass_hero/program_catalog/create_program_integration_test.exs`
Expected: All PASS

**Step 3: Commit**

```bash
git add test/klass_hero/program_catalog/create_program_integration_test.exs
git commit -m "test: update integration tests for domain validation error format"
```

---

### Task 10: UpdateProgram use case (new)

**Files:**
- Create: `lib/klass_hero/program_catalog/application/use_cases/update_program.ex`
- Create: `test/klass_hero/program_catalog/update_program_integration_test.exs`

**Step 1: Write integration test**

```elixir
defmodule KlassHero.ProgramCatalog.UpdateProgramIntegrationTest do
  use KlassHero.DataCase

  alias KlassHero.ProgramCatalog
  alias KlassHero.ProviderFixtures

  describe "update_program/2" do
    setup do
      provider = ProviderFixtures.provider_profile_fixture()

      {:ok, program} =
        ProgramCatalog.create_program(%{
          provider_id: provider.id,
          title: "Original Title",
          description: "Original description",
          category: "sports",
          price: Decimal.new("100.00")
        })

      %{program: program}
    end

    test "updates title successfully", %{program: program} do
      assert {:ok, updated} =
               ProgramCatalog.update_program(program.id, %{title: "New Title"})

      assert updated.title == "New Title"
      assert updated.description == "Original description"
    end

    test "updates multiple fields", %{program: program} do
      assert {:ok, updated} =
               ProgramCatalog.update_program(program.id, %{
                 title: "Updated",
                 price: Decimal.new("200.00"),
                 spots_available: 15
               })

      assert updated.title == "Updated"
      assert updated.price == Decimal.new("200.00")
      assert updated.spots_available == 15
    end

    test "rejects invalid changes (empty title)", %{program: program} do
      assert {:error, _} = ProgramCatalog.update_program(program.id, %{title: ""})

      # Verify original unchanged
      assert {:ok, unchanged} = ProgramCatalog.get_program_by_id(program.id)
      assert unchanged.title == "Original Title"
    end

    test "returns not_found for invalid ID" do
      assert {:error, :not_found} =
               ProgramCatalog.update_program(Ecto.UUID.generate(), %{title: "New"})
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/program_catalog/update_program_integration_test.exs --max-failures 1`
Expected: FAIL — `ProgramCatalog.update_program/2` undefined

**Step 3: Create UpdateProgram use case**

```elixir
defmodule KlassHero.ProgramCatalog.Application.UseCases.UpdateProgram do
  @moduledoc """
  Use case for updating an existing program.

  Orchestrates: load aggregate -> apply changes through domain model -> persist.
  Optimistic locking via lock_version on the loaded aggregate.
  """

  alias KlassHero.ProgramCatalog.Domain.Models.Program

  @repository Application.compile_env!(:klass_hero, [:program_catalog, :repository])

  def execute(id, changes) when is_binary(id) and is_map(changes) do
    with {:ok, program} <- @repository.get_by_id(id),
         {:ok, updated} <- Program.apply_changes(program, changes),
         {:ok, persisted} <- @repository.update(updated) do
      {:ok, persisted}
    end
  end
end
```

**Step 4: Add `update_program/2` to the facade**

In `lib/klass_hero/program_catalog.ex`, add the alias and function:

Add `UpdateProgram` to the alias group:
```elixir
alias KlassHero.ProgramCatalog.Application.UseCases.{
  CreateProgram,
  GetProgramById,
  ListAllPrograms,
  ListFeaturedPrograms,
  ListProgramsPaginated,
  ListProviderPrograms,
  UpdateProgram
}
```

Add the function in the "Program Creation" section (or rename section to "Program Commands"):

```elixir
@doc """
Updates an existing program.

Loads the current program, applies changes through the domain model,
and persists with optimistic locking.

## Parameters

- `id` - Program UUID
- `changes` - Map of fields to update

## Returns

- `{:ok, Program.t()}` on success
- `{:error, :not_found}` if program doesn't exist
- `{:error, :stale_data}` if concurrent modification detected
- `{:error, errors}` on validation failure
"""
@spec update_program(String.t(), map()) :: {:ok, Program.t()} | {:error, term()}
def update_program(id, changes) when is_binary(id) and is_map(changes) do
  UpdateProgram.execute(id, changes)
end
```

**Step 5: Run tests**

Run: `mix test test/klass_hero/program_catalog/update_program_integration_test.exs`
Expected: All PASS

**Step 6: Commit**

```bash
git add lib/klass_hero/program_catalog/application/use_cases/update_program.ex test/klass_hero/program_catalog/update_program_integration_test.exs lib/klass_hero/program_catalog.ex
git commit -m "feat: add UpdateProgram use case with domain validation"
```

---

### Task 11: Run full test suite and fix any breakage

**Step 1: Run full test suite**

Run: `mix test`
Expected: All PASS

**Step 2: If any repository tests fail due to `create/1` signature change**

The repository test's `insert_program` helper uses `ProgramSchema.changeset/2` directly (not the repository), so it should be unaffected. But verify.

**Step 3: Run precommit checks**

Run: `mix precommit`
Expected: Compiles with `--warnings-as-errors`, formats, all tests pass

**Step 4: Commit any remaining fixes**

```bash
git add -A
git commit -m "fix: resolve any test breakage from aggregate redesign"
```

---

### Task 12: Web layer — update instructor attrs shape in dashboard_live

**Files:**
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex`

The web layer currently passes instructor as flat fields (`instructor_id`, `instructor_name`, `instructor_headshot_url`). The aggregate's `create/1` now expects an `instructor` key with a map value.

**Step 1: Check current instructor attrs construction in dashboard_live.ex**

Look for `maybe_add_instructor` function and update it to build the nested `instructor` map:

```elixir
# Before (flat fields):
%{instructor_id: id, instructor_name: name, instructor_headshot_url: url}

# After (nested map for aggregate):
%{instructor: %{id: id, name: name, headshot_url: url}}
```

**Step 2: Run integration tests**

Run: `mix test test/klass_hero/program_catalog/create_program_integration_test.exs`
Expected: All PASS

**Step 3: Run full precommit**

Run: `mix precommit`
Expected: All PASS

**Step 4: Commit**

```bash
git add lib/klass_hero_web/live/provider/dashboard_live.ex
git commit -m "refactor: dashboard passes instructor as nested map for aggregate"
```
