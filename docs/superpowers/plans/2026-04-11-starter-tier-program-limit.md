# Starter Tier Program Limit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce the starter provider tier's 2-program limit, tracking program origin (`self_posted` / `business_assigned`) and only counting self-posted programs toward the cap.

**Architecture:** Add an `origin` column to the `programs` table (default `"self_posted"`). The `CreateProgram` use case checks `Entitlements.can_create_program?/2` before persisting. The provider dashboard disables the "New Program" button when at capacity. The `provider_tier_bypass` feature flag continues to override limits when active.

**Tech Stack:** Elixir 1.20, Phoenix 1.8, LiveView 1.1, Ecto, PostgreSQL

**Spec:** `docs/superpowers/specs/2026-04-11-starter-tier-program-limit-design.md`

**Key conventions:**
- Use Tidewave MCP (`project_eval`, `get_docs`, `execute_sql_query`) for verification at each step
- Use `mix test path/to/test.exs:LINE` for targeted test runs
- Use `mix precommit` before final commit
- Ports are split by operation: `ForCreatingPrograms`, `ForListingPrograms`, `ForUpdatingPrograms` (not a single `ForStoringPrograms`)
- Factory defaults: `provider_profile_schema` has `subscription_tier: "professional"` — override to `"starter"` for limit tests
- The `register_and_log_in_provider` helper creates a **professional** tier provider

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `priv/repo/migrations/TIMESTAMP_add_origin_to_programs.exs` | Create | Migration: add `origin` column + composite index |
| `lib/klass_hero/program_catalog/domain/models/program.ex` | Modify | Add `:origin` field to struct, type, `create/1`, `build_base/3` |
| `lib/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema.ex` | Modify | Add `:origin` field, include in `create_changeset/2` |
| `lib/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper.ex` | Modify | Map `origin` string <-> atom in `to_domain/1` and `to_schema/1` |
| `lib/klass_hero/program_catalog/domain/ports/for_creating_programs.ex` | Modify | Add `count_by_provider_and_origin/2` callback |
| `lib/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_repository.ex` | Modify | Implement `count_by_provider_and_origin/2` |
| `lib/klass_hero/program_catalog/application/use_cases/create_program.ex` | Modify | Add entitlement guard, accept `tier_holder` param |
| `lib/klass_hero/program_catalog.ex` | Modify | Update `create_program/1` to `create_program/2` |
| `lib/klass_hero_web/components/provider_components.ex` | Modify | Disable "New Program" button when at program limit |
| `lib/klass_hero_web/live/provider/dashboard_live.ex` | Modify | Pass tier_holder to `create_program/2`, handle `:program_limit_reached` |
| `test/support/factory.ex` | Modify | Add `origin: "self_posted"` to `program_schema_factory` |
| Tests (listed per task) | Create/Modify | Test files for each layer |

---

## Task 1: Migration — Add `origin` to `programs`

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_origin_to_programs.exs`

- [ ] **Step 1: Generate the migration file**

```bash
mix ecto.gen.migration add_origin_to_programs
```

- [ ] **Step 2: Write the migration**

```elixir
defmodule KlassHero.Repo.Migrations.AddOriginToPrograms do
  use Ecto.Migration

  def change do
    alter table(:programs) do
      add :origin, :string, null: false, default: "self_posted"
    end

    create index(:programs, [:provider_id, :origin])
  end
end
```

- [ ] **Step 3: Run the migration**

```bash
mix ecto.migrate
```

Expected: Migration succeeds. All existing programs get `origin = "self_posted"`.

- [ ] **Step 4: Verify with Tidewave**

```elixir
# Via Tidewave project_eval:
KlassHero.Repo.aggregate(
  from(p in "programs", where: p.origin == "self_posted"),
  :count
)
# Should return the total number of programs (all backfilled)
```

Also verify with Tidewave `execute_sql_query`:
```sql
SELECT origin, COUNT(*) FROM programs GROUP BY origin;
```
Expected: one row `self_posted | <total_count>`.

- [ ] **Step 5: Commit**

```bash
git add priv/repo/migrations/*_add_origin_to_programs.exs
git commit -m "feat: add origin column to programs table (#360)"
```

---

## Task 2: Domain Model — Add `origin` field to `Program`

**Files:**
- Modify: `lib/klass_hero/program_catalog/domain/models/program.ex`
- Test: `test/klass_hero/program_catalog/domain/models/program_test.exs`

- [ ] **Step 1: Write the failing test**

Add to `test/klass_hero/program_catalog/domain/models/program_test.exs`:

```elixir
describe "origin field" do
  test "create/1 defaults origin to :self_posted" do
    attrs = %{
      provider_id: "550e8400-e29b-41d4-a716-446655440000",
      title: "Test Program",
      description: "A test program",
      category: "sports",
      price: Decimal.new("50.00")
    }

    assert {:ok, program} = Program.create(attrs)
    assert program.origin == :self_posted
  end

  test "new/1 preserves origin from trusted data" do
    attrs = valid_attrs(%{origin: :business_assigned})

    assert {:ok, program} = Program.new(attrs)
    assert program.origin == :business_assigned
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/klass_hero/program_catalog/domain/models/program_test.exs --only describe:"origin field"
```

Expected: FAIL — `origin` field doesn't exist on `Program` struct.

- [ ] **Step 3: Add `origin` to the Program struct**

In `lib/klass_hero/program_catalog/domain/models/program.ex`:

Add `:origin` to the defstruct (after `:cover_image_url`):

```elixir
defstruct [
  :id,
  :provider_id,
  :title,
  :description,
  :category,
  :age_range,
  :price,
  :pricing_period,
  :end_date,
  :lock_version,
  :location,
  :cover_image_url,
  :origin,
  :instructor,
  :inserted_at,
  :updated_at,
  :meeting_start_time,
  :meeting_end_time,
  :start_date,
  meeting_days: [],
  registration_period: %RegistrationPeriod{}
]
```

Add to the `@type t` spec:

```elixir
origin: :self_posted | :business_assigned | nil,
```

In `build_base/3`, set `origin: :self_posted` in the struct construction (around line 183-200):

```elixir
{:ok,
 %__MODULE__{
   title: attrs[:title],
   description: attrs[:description],
   category: attrs[:category],
   price: attrs[:price],
   provider_id: attrs[:provider_id],
   origin: :self_posted,
   meeting_days: attrs[:meeting_days] || [],
   # ... rest unchanged
 }}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
mix test test/klass_hero/program_catalog/domain/models/program_test.exs
```

Expected: All tests PASS, including the two new ones.

- [ ] **Step 5: Verify with Tidewave**

```elixir
# Via Tidewave project_eval:
alias KlassHero.ProgramCatalog.Domain.Models.Program
{:ok, p} = Program.create(%{
  provider_id: "test-id",
  title: "Test",
  description: "Test desc",
  category: "sports",
  price: Decimal.new("10.00")
})
p.origin
# Should return :self_posted
```

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/program_catalog/domain/models/program.ex test/klass_hero/program_catalog/domain/models/program_test.exs
git commit -m "feat: add origin field to Program domain model (#360)"
```

---

## Task 3: Schema & Mapper — Add `origin` to persistence layer

**Files:**
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema.ex`
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper.ex`
- Modify: `test/support/factory.ex`
- Test: `test/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper_test.exs`

- [ ] **Step 1: Write the failing mapper test**

Add to `test/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper_test.exs`:

```elixir
describe "origin field mapping" do
  test "to_domain/1 maps origin string to atom" do
    schema = %ProgramSchema{
      id: Ecto.UUID.generate(),
      title: "Test",
      description: "Test desc",
      category: "sports",
      price: Decimal.new("50.00"),
      origin: "self_posted",
      meeting_days: [],
      lock_version: 1,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    program = ProgramMapper.to_domain(schema)
    assert program.origin == :self_posted
  end

  test "to_domain/1 maps business_assigned origin" do
    schema = %ProgramSchema{
      id: Ecto.UUID.generate(),
      title: "Test",
      description: "Test desc",
      category: "sports",
      price: Decimal.new("50.00"),
      origin: "business_assigned",
      meeting_days: [],
      lock_version: 1,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    program = ProgramMapper.to_domain(schema)
    assert program.origin == :business_assigned
  end

  test "to_schema/1 maps origin atom to string" do
    program = %Program{
      title: "Test",
      description: "Test desc",
      category: "sports",
      price: Decimal.new("50.00"),
      origin: :self_posted,
      meeting_days: [],
      registration_period: %RegistrationPeriod{}
    }

    attrs = ProgramMapper.to_schema(program)
    assert attrs.origin == "self_posted"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
mix test test/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper_test.exs --only describe:"origin field mapping"
```

Expected: FAIL — `origin` field doesn't exist on `ProgramSchema`.

- [ ] **Step 3: Add `origin` to ProgramSchema**

In `lib/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema.ex`:

Add the field in the schema block (after `cover_image_url`):

```elixir
field :origin, :string, default: "self_posted"
```

Add to the `@type t` spec:

```elixir
origin: String.t() | nil,
```

Add `:origin` to the `create_changeset/2` `maybe_put_change` calls (after the `maybe_put_change(:instructor_headshot_url, attrs)` line, around line 164):

```elixir
|> maybe_put_change(:origin, attrs)
```

- [ ] **Step 4: Update the mapper**

In `lib/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper.ex`:

In `to_domain/1`, add origin mapping (after `cover_image_url:`):

```elixir
origin: safe_to_atom(schema.origin),
```

Add the `safe_to_atom/1` helper at the bottom of the module:

```elixir
defp safe_to_atom("self_posted"), do: :self_posted
defp safe_to_atom("business_assigned"), do: :business_assigned
defp safe_to_atom(nil), do: :self_posted
```

In `to_schema/1`, add origin to the base map (after `cover_image_url:`):

```elixir
origin: to_string(program.origin),
```

- [ ] **Step 5: Update the factory**

In `test/support/factory.ex`, add `origin: "self_posted"` to `program_schema_factory` (after `end_date: nil`, around line 118):

```elixir
origin: "self_posted"
```

- [ ] **Step 6: Run mapper tests**

```bash
mix test test/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper_test.exs
```

Expected: All tests PASS.

- [ ] **Step 7: Run all program catalog tests**

```bash
mix test test/klass_hero/program_catalog/
```

Expected: All tests PASS. Existing tests should still work since `origin` defaults to `"self_posted"`.

- [ ] **Step 8: Commit**

```bash
git add lib/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_schema.ex lib/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper.ex test/klass_hero/program_catalog/adapters/driven/persistence/mappers/program_mapper_test.exs test/support/factory.ex
git commit -m "feat: add origin field to program schema and mapper (#360)"
```

---

## Task 4: Port & Repository — Add `count_by_provider_and_origin/2`

**Files:**
- Modify: `lib/klass_hero/program_catalog/domain/ports/for_creating_programs.ex`
- Modify: `lib/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_repository.ex`
- Test: `test/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_repository_test.exs`

- [ ] **Step 1: Write the failing repository test**

Add to `test/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_repository_test.exs`:

```elixir
describe "count_by_provider_and_origin/2" do
  test "returns count of programs with matching origin for a provider" do
    provider_id = Ecto.UUID.generate()

    insert_program(%{
      title: "Program 1",
      description: "Desc",
      age_range: "6-10",
      price: Decimal.new("10.00"),
      pricing_period: "per month",
      provider_id: provider_id,
      origin: "self_posted"
    })

    insert_program(%{
      title: "Program 2",
      description: "Desc",
      age_range: "6-10",
      price: Decimal.new("20.00"),
      pricing_period: "per month",
      provider_id: provider_id,
      origin: "self_posted"
    })

    insert_program(%{
      title: "Business Program",
      description: "Desc",
      age_range: "6-10",
      price: Decimal.new("30.00"),
      pricing_period: "per month",
      provider_id: provider_id,
      origin: "business_assigned"
    })

    assert ProgramRepository.count_by_provider_and_origin(provider_id, :self_posted) == 2
    assert ProgramRepository.count_by_provider_and_origin(provider_id, :business_assigned) == 1
  end

  test "returns 0 when no programs match" do
    provider_id = Ecto.UUID.generate()
    assert ProgramRepository.count_by_provider_and_origin(provider_id, :self_posted) == 0
  end

  test "does not count programs from other providers" do
    provider_a = Ecto.UUID.generate()
    provider_b = Ecto.UUID.generate()

    insert_program(%{
      title: "Provider A Program",
      description: "Desc",
      age_range: "6-10",
      price: Decimal.new("10.00"),
      pricing_period: "per month",
      provider_id: provider_a,
      origin: "self_posted"
    })

    insert_program(%{
      title: "Provider B Program",
      description: "Desc",
      age_range: "6-10",
      price: Decimal.new("20.00"),
      pricing_period: "per month",
      provider_id: provider_b,
      origin: "self_posted"
    })

    assert ProgramRepository.count_by_provider_and_origin(provider_a, :self_posted) == 1
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
mix test test/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_repository_test.exs --only describe:"count_by_provider_and_origin/2"
```

Expected: FAIL — function `count_by_provider_and_origin/2` is undefined.

- [ ] **Step 3: Add callback to the port**

In `lib/klass_hero/program_catalog/domain/ports/for_creating_programs.ex`, add:

```elixir
@callback count_by_provider_and_origin(
            provider_id :: String.t(),
            origin :: :self_posted | :business_assigned
          ) :: non_neg_integer()
```

- [ ] **Step 4: Implement in the repository**

In `lib/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_repository.ex`, add:

```elixir
@doc """
Counts programs for a provider filtered by origin.

Used by the CreateProgram use case to enforce tier-based program limits.
Only self-posted programs count toward the limit.
"""
@impl true
def count_by_provider_and_origin(provider_id, origin) when is_atom(origin) do
  origin_string = to_string(origin)

  ProgramSchema
  |> where([p], p.provider_id == ^provider_id and p.origin == ^origin_string)
  |> Repo.aggregate(:count)
end
```

- [ ] **Step 5: Run repository tests**

```bash
mix test test/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_repository_test.exs
```

Expected: All tests PASS.

- [ ] **Step 6: Verify with Tidewave**

```elixir
# Via Tidewave project_eval:
alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepository
# Should return 0 or the count of self_posted programs for a known provider
ProgramRepository.count_by_provider_and_origin("some-provider-id", :self_posted)
```

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero/program_catalog/domain/ports/for_creating_programs.ex lib/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_repository.ex test/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_repository_test.exs
git commit -m "feat: add count_by_provider_and_origin to program repository (#360)"
```

---

## Task 5: Use Case — Add entitlement guard to `CreateProgram`

**Files:**
- Modify: `lib/klass_hero/program_catalog/application/use_cases/create_program.ex`
- Modify: `lib/klass_hero/program_catalog.ex`
- Test: `test/klass_hero/program_catalog/create_program_integration_test.exs`

- [ ] **Step 1: Write the failing integration tests**

Add to `test/klass_hero/program_catalog/create_program_integration_test.exs`:

```elixir
describe "create_program/2 with program limit" do
  test "allows creation when starter provider is under limit" do
    provider = ProviderFixtures.provider_profile_fixture(%{subscription_tier: "starter"})

    assert {:ok, program} =
             ProgramCatalog.create_program(
               %{
                 provider_id: provider.id,
                 title: "First Program",
                 description: "A valid program",
                 category: "arts",
                 price: Decimal.new("50.00")
               },
               provider
             )

    assert program.origin == :self_posted
  end

  test "rejects creation when starter provider is at limit" do
    provider = ProviderFixtures.provider_profile_fixture(%{subscription_tier: "starter"})

    # Create 2 programs to reach the limit
    for i <- 1..2 do
      {:ok, _} =
        ProgramCatalog.create_program(
          %{
            provider_id: provider.id,
            title: "Program #{i}",
            description: "A valid program",
            category: "arts",
            price: Decimal.new("50.00")
          },
          provider
        )
    end

    # Third program should be rejected
    assert {:error, :program_limit_reached} =
             ProgramCatalog.create_program(
               %{
                 provider_id: provider.id,
                 title: "Third Program",
                 description: "Should be rejected",
                 category: "arts",
                 price: Decimal.new("50.00")
               },
               provider
             )
  end

  test "allows creation for professional provider beyond starter limit" do
    provider = ProviderFixtures.provider_profile_fixture(%{subscription_tier: "professional"})

    for i <- 1..3 do
      assert {:ok, _} =
               ProgramCatalog.create_program(
                 %{
                   provider_id: provider.id,
                   title: "Program #{i}",
                   description: "A valid program",
                   category: "arts",
                   price: Decimal.new("50.00")
                 },
                 provider
               )
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
mix test test/klass_hero/program_catalog/create_program_integration_test.exs --only describe:"create_program/2 with program limit"
```

Expected: FAIL — `create_program/2` doesn't exist yet (only `create_program/1`).

- [ ] **Step 3: Update the use case**

In `lib/klass_hero/program_catalog/application/use_cases/create_program.ex`:

```elixir
defmodule KlassHero.ProgramCatalog.Application.UseCases.CreateProgram do
  @moduledoc """
  Use case for creating a new program.

  Orchestrates entitlement checking, domain validation, and persistence:
  1. Checks program limit against provider's subscription tier
  2. Builds and validates the Program aggregate via Program.create/1
  3. Persists via the repository adapter
  4. Dispatches domain events on success
  """

  alias KlassHero.ProgramCatalog.Domain.Events.ProgramEvents
  alias KlassHero.ProgramCatalog.Domain.Models.Program
  alias KlassHero.Shared.DomainEventBus
  alias KlassHero.Shared.Entitlements

  require Logger

  @repository Application.compile_env!(:klass_hero, [:program_catalog, :repository])

  def execute(attrs, tier_holder) when is_map(attrs) do
    with :ok <- check_program_limit(attrs[:provider_id], tier_holder),
         {:ok, program} <- Program.create(attrs),
         {:ok, persisted} <- @repository.create(program) do
      dispatch_event(persisted)
      {:ok, persisted}
    end
  end

  defp check_program_limit(provider_id, tier_holder) do
    current_count = @repository.count_by_provider_and_origin(provider_id, :self_posted)

    if Entitlements.can_create_program?(tier_holder, current_count) do
      :ok
    else
      {:error, :program_limit_reached}
    end
  end

  # dispatch_event/1 unchanged...
end
```

**Important:** Keep the existing `dispatch_event/1` function exactly as-is. Only change `execute/1` → `execute/2` and add `check_program_limit/2`.

- [ ] **Step 4: Update the public API**

In `lib/klass_hero/program_catalog.ex`, update `create_program`:

```elixir
@doc """
Creates a new program.

## Parameters

- `attrs` - Map with: title, description, category, price, provider_id.
  Optional: location, cover_image_url, instructor_id, instructor_name, instructor_headshot_url.
- `tier_holder` - Provider domain model (must have `:subscription_tier` field).
  Used to check program creation entitlement.

## Returns

- `{:ok, Program.t()}` on success
- `{:error, :program_limit_reached}` if provider has reached their tier's program limit
- `{:error, changeset}` on validation failure
"""
@spec create_program(map(), map()) :: {:ok, Program.t()} | {:error, term()}
def create_program(attrs, tier_holder) when is_map(attrs) do
  CreateProgram.execute(attrs, tier_holder)
end
```

- [ ] **Step 5: Update existing tests**

The existing `create_program/1` tests in `create_program_integration_test.exs` need updating to pass a `tier_holder`. Add a setup block and update each existing test:

At the top of the existing `describe "create_program/1"` block, rename to `"create_program/2"` and add a setup:

```elixir
describe "create_program/2" do
  setup do
    # Use professional tier to avoid limit interference with existing tests
    provider = ProviderFixtures.provider_profile_fixture(%{subscription_tier: "professional"})
    %{provider: provider}
  end

  test "creates program with required fields", %{provider: provider} do
    assert {:ok, program} =
             ProgramCatalog.create_program(
               %{
                 provider_id: provider.id,
                 title: "Art Adventures",
                 description: "Creative art program for kids",
                 category: "arts",
                 price: Decimal.new("50.00")
               },
               provider
             )
    # ... rest of assertions unchanged
  end

  # ... update all other existing tests similarly: add provider to setup,
  # pass provider as second arg to create_program
end
```

- [ ] **Step 6: Run integration tests**

```bash
mix test test/klass_hero/program_catalog/create_program_integration_test.exs
```

Expected: All tests PASS.

- [ ] **Step 7: Check for compile warnings**

```bash
mix compile --warnings-as-errors 2>&1 | head -30
```

Expected: No warnings. If any callers of the old `create_program/1` exist elsewhere, they will produce compile warnings. Check and update them (likely just the dashboard LiveView, handled in Task 6).

- [ ] **Step 8: Commit**

```bash
git add lib/klass_hero/program_catalog/application/use_cases/create_program.ex lib/klass_hero/program_catalog.ex test/klass_hero/program_catalog/create_program_integration_test.exs
git commit -m "feat: enforce program limit in CreateProgram use case (#360)"
```

---

## Task 6: Dashboard — Wire up limit enforcement in UI

**Files:**
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex`
- Modify: `lib/klass_hero_web/components/provider_components.ex`
- Test: `test/klass_hero_web/live/provider/dashboard_program_creation_test.exs`

- [ ] **Step 1: Write the failing LiveView tests**

Add new describe block to `test/klass_hero_web/live/provider/dashboard_program_creation_test.exs`:

```elixir
describe "program limit enforcement" do
  test "disables new program button when at starter limit", %{conn: conn, provider: provider} do
    # Override provider to starter tier
    provider
    |> Ecto.Changeset.change(%{subscription_tier: "starter"})
    |> Repo.update!()

    # Create 2 programs to reach the starter limit
    for i <- 1..2 do
      Repo.insert!(%KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema{
        id: Ecto.UUID.generate(),
        title: "Program #{i}",
        description: "Description for program #{i}",
        category: "arts",
        price: Decimal.new("50.00"),
        provider_id: provider.id,
        origin: "self_posted"
      })
    end

    {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

    # Button should be disabled
    assert has_element?(view, "#new-program-btn[disabled]")
  end

  test "shows error when creation is rejected at limit", %{conn: conn, provider: provider} do
    # Override provider to starter tier
    provider
    |> Ecto.Changeset.change(%{subscription_tier: "starter"})
    |> Repo.update!()

    # Create 2 programs to reach the starter limit
    for i <- 1..2 do
      Repo.insert!(%KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema{
        id: Ecto.UUID.generate(),
        title: "Program #{i}",
        description: "Description for program #{i}",
        category: "arts",
        price: Decimal.new("50.00"),
        provider_id: provider.id,
        origin: "self_posted"
      })
    end

    {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

    # Force-send the add_program event (bypassing disabled button)
    render_hook(view, "add_program")

    view
    |> form("#program-form", %{
      "program_schema" => %{
        "title" => "Third Program",
        "description" => "Should be rejected",
        "category" => "arts",
        "price" => "50.00"
      }
    })
    |> render_submit()

    assert render(view) =~ "program limit"
  end

  test "enables new program button when under limit", %{conn: conn, provider: provider} do
    # Override provider to starter tier (0 programs, limit is 2)
    provider
    |> Ecto.Changeset.change(%{subscription_tier: "starter"})
    |> Repo.update!()

    {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

    # Button should be enabled (not disabled)
    refute has_element?(view, "#new-program-btn[disabled]")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
mix test test/klass_hero_web/live/provider/dashboard_program_creation_test.exs --only describe:"program limit enforcement"
```

Expected: FAIL — button is not disabled, creation not rejected.

- [ ] **Step 3: Update the dashboard LiveView**

In `lib/klass_hero_web/live/provider/dashboard_live.ex`:

**3a.** Add a `can_create_program?` assign in mount (after `update_program_slots`, around line 85):

```elixir
|> update_program_slots(programs_count)
|> update_can_create_program()
```

**3b.** Add the `update_can_create_program/1` helper (near `update_program_slots/2`, around line 1517):

```elixir
defp update_can_create_program(socket) do
  provider = socket.assigns.current_scope.provider
  used = socket.assigns.business.program_slots_used
  can_create? = Entitlements.can_create_program?(provider, used)
  assign(socket, can_create_program?: can_create?)
end
```

Add the alias at the top of the module:

```elixir
alias KlassHero.Shared.Entitlements
```

**3c.** Update `update_program_slots/2` to also recalculate `can_create_program?`:

```elixir
defp update_program_slots(socket, count) do
  business = %{socket.assigns.business | program_slots_used: count}

  socket
  |> assign(business: business)
  |> update_can_create_program()
end
```

**3d.** Update `create_new_program/4` to pass tier_holder (around line 795):

Change:
```elixir
{:ok, program} <- ProgramCatalog.create_program(attrs) do
```
To:
```elixir
{:ok, program} <- ProgramCatalog.create_program(attrs, socket.assigns.current_scope.provider) do
```

**3e.** Add error handling for `:program_limit_reached` in the `else` block of `create_new_program/4` (before the existing `{:error, :instructor_not_found}` clause):

```elixir
{:error, :program_limit_reached} ->
  {:noreply,
   put_flash(
     socket,
     :error,
     gettext("You've reached your program limit. Upgrade your plan to add more programs.")
   )}
```

**3f.** Also update the programs-tab refresh path if it exists. Search for any other call to `ProgramCatalog.create_program` in the file and update similarly. Also update the line around 1560 where `update_program_slots` is called after a refresh to also recalculate:

This should already work because we updated `update_program_slots/2` to call `update_can_create_program/1`.

- [ ] **Step 4: Update the provider component button**

In `lib/klass_hero_web/components/provider_components.ex`, update the "New Program" button (around line 400-414):

Change the `disabled` attribute from:
```elixir
disabled={@business.verification_status != :verified}
```
To:
```elixir
disabled={@business.verification_status != :verified or not @can_create_program?}
```

Update the class conditional from:
```elixir
if(@business.verification_status == :verified,
  do: "bg-hero-yellow hover:bg-hero-yellow-dark text-hero-charcoal",
  else: "bg-hero-grey-200 text-hero-grey-400 cursor-not-allowed"
)
```
To:
```elixir
if(@business.verification_status == :verified and @can_create_program?,
  do: "bg-hero-yellow hover:bg-hero-yellow-dark text-hero-charcoal",
  else: "bg-hero-grey-200 text-hero-grey-400 cursor-not-allowed"
)
```

Update the tooltip condition from:
```elixir
:if={@business.verification_status != :verified}
```
To:
```elixir
:if={@business.verification_status != :verified or not @can_create_program?}
```

Update the tooltip text to handle both cases:

```heex
<%= cond do %>
  <% @business.verification_status != :verified -> %>
    {gettext("Complete business verification to create programs.")}
  <% not @can_create_program? -> %>
    {gettext("You've reached your program limit. Upgrade your plan to add more programs.")}
  <% true -> %>
<% end %>
```

**Note:** The component needs the `@can_create_program?` assign. Check how the component is called and add the assign to its attributes. The component likely receives assigns via the caller — verify the component function signature accepts this new assign.

- [ ] **Step 5: Run the new LiveView tests**

```bash
mix test test/klass_hero_web/live/provider/dashboard_program_creation_test.exs
```

Expected: All tests PASS, including the new program limit tests.

- [ ] **Step 6: Run all provider dashboard tests**

```bash
mix test test/klass_hero_web/live/provider/
```

Expected: All tests PASS. Existing tests use `professional` tier (limit: 5) and create at most 1-2 programs, so they should remain unaffected.

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero_web/live/provider/dashboard_live.ex lib/klass_hero_web/components/provider_components.ex test/klass_hero_web/live/provider/dashboard_program_creation_test.exs
git commit -m "feat: enforce program limit in provider dashboard UI (#360)"
```

---

## Task 7: Final Verification & Cleanup

**Files:** None new — verification only.

- [ ] **Step 1: Run full precommit checks**

```bash
mix precommit
```

Expected: Compile (no warnings), format, test — all pass.

- [ ] **Step 2: Verify end-to-end with Tidewave**

```elixir
# Via Tidewave project_eval — create a starter provider and test the limit:
alias KlassHero.ProgramCatalog
alias KlassHero.ProviderFixtures

provider = ProviderFixtures.provider_profile_fixture(%{subscription_tier: "starter"})

# First program — should succeed
{:ok, p1} = ProgramCatalog.create_program(
  %{provider_id: provider.id, title: "P1", description: "Desc", category: "arts", price: Decimal.new("10")},
  provider
)
p1.origin  # => :self_posted

# Second program — should succeed
{:ok, _p2} = ProgramCatalog.create_program(
  %{provider_id: provider.id, title: "P2", description: "Desc", category: "arts", price: Decimal.new("10")},
  provider
)

# Third program — should be rejected
{:error, :program_limit_reached} = ProgramCatalog.create_program(
  %{provider_id: provider.id, title: "P3", description: "Desc", category: "arts", price: Decimal.new("10")},
  provider
)
```

- [ ] **Step 3: Verify SQL state**

Via Tidewave `execute_sql_query`:
```sql
SELECT p.origin, COUNT(*)
FROM programs p
GROUP BY p.origin;
```

- [ ] **Step 4: Squash-commit if needed, push**

```bash
git push
```
