---
name: gen-migration
description: >-
  Scaffold a new database-backed entity for the DDD/Ports & Adapters architecture.
  Generates an Ecto migration, domain model struct, Ecto schema, mapper,
  repository, port behaviour, and wires DI in config. Invoke with:
  /gen-migration <context> <entity> [field:type ...] [--references table:field]
  Example: /gen-migration messaging reaction user_id:binary_id message_id:binary_id emoji:string --references users:user_id messages:message_id
---

# Gen-Migration

Scaffold a complete database-backed entity following the project's DDD/Ports & Adapters architecture.

**Type:** Rigid workflow. Follow steps exactly.

---

## Step 1: Parse Arguments

Extract from `$ARGUMENTS`:
- **context** (required): The bounded context name in snake_case (e.g., `messaging`, `enrollment`, `provider`)
- **entity** (required): The entity name in snake_case (e.g., `reaction`, `program_review`)
- **fields** (optional): Space-separated `name:type` pairs
- **--references** (optional): Space-separated `table:field` pairs for foreign keys

Validate:
1. Context must exist under `lib/klass_hero/` — check the directory exists
2. Entity name must be snake_case
3. Field types must be valid Ecto migration types: `:string`, `:text`, `:integer`, `:boolean`, `:decimal`, `:binary_id`, `:utc_datetime`, `:utc_datetime_usec`, `:date`, `:map`, `{:array, :string}`

If context doesn't exist, ask: "Context `{name}` doesn't exist. Should I create the full context directory structure?"

If no fields are provided, ask the user to describe the entity's fields.

## Step 2: Derive Names

From the parsed arguments, compute all module names:

| Concept | Derivation | Example (context=messaging, entity=reaction) |
|---------|-----------|-----------------------------------------------|
| Table name | Pluralized snake_case | `reactions` |
| Module suffix | PascalCase | `Reaction` |
| Domain model | `KlassHero.{Context}.Domain.Models.{Module}` | `KlassHero.Messaging.Domain.Models.Reaction` |
| Schema | `KlassHero.{Context}.Adapters.Driven.Persistence.Schemas.{Module}Schema` | `...Schemas.ReactionSchema` |
| Mapper | `KlassHero.{Context}.Adapters.Driven.Persistence.Mappers.{Module}Mapper` | `...Mappers.ReactionMapper` |
| Repository | `KlassHero.{Context}.Adapters.Driven.Persistence.Repositories.{Module}Repository` | `...Repositories.ReactionRepository` |
| Port | `KlassHero.{Context}.Domain.Ports.ForManaging{Pluralized}` | `...Ports.ForManagingReactions` |
| Config key | `for_managing_{pluralized}` | `:for_managing_reactions` |

Present the derived names to the user for confirmation before generating.

## Step 3: Generate Migration

**File:** `priv/repo/migrations/{timestamp}_create_{table_name}.exs`

Generate timestamp: `date -u +"%Y%m%d%H%M%S"`

Follow the project's migration conventions exactly:

```elixir
defmodule KlassHero.Repo.Migrations.Create{PluralizedPascal} do
  use Ecto.Migration

  def change do
    create table(:{table_name}, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # For each reference field:
      add :{field}, references(:{table}, type: :binary_id, on_delete: :delete_all),
        null: false

      # For each regular field:
      add :{field}, :{type}, null: false  # or nullable if optional

      timestamps(type: :utc_datetime_usec)
    end

    # Index on every foreign key column
    create index(:{table_name}, [:{fk_field}])

    # Unique indexes if specified
  end
end
```

**Conventions:**
- `primary_key: false` on table, manual `:id` with `:binary_id`
- `timestamps(type: :utc_datetime_usec)` — older tables may use `:utc_datetime`; all new tables use microsecond precision
- All references use `type: :binary_id` and `on_delete: :delete_all`
- `null: false` on required fields
- Explicit `create index` on every foreign key column

## Step 4: Generate Domain Model

**File:** `lib/klass_hero/{context}/domain/models/{entity}.ex`

```elixir
defmodule KlassHero.{Context}.Domain.Models.{Module} do
  @moduledoc """
  {Entity description} in the {Context} bounded context.
  """

  @enforce_keys [:id, {required_fields}]

  defstruct [
    :id,
    {all_fields},
    :inserted_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          {field_typespecs},
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }
end
```

**Conventions:**
- `@enforce_keys` includes `:id` and all business-required fields
- `defstruct` lists all fields plus `:inserted_at`, `:updated_at`
- `@type t` with full typespec for every field
- String IDs (`String.t()`), timestamps (`DateTime.t() | nil`)
- NO Ecto, NO Phoenix, NO infrastructure imports — pure Elixir only

## Step 5: Generate Schema

**File:** `lib/klass_hero/{context}/adapters/driven/persistence/schemas/{entity}_schema.ex`

```elixir
defmodule KlassHero.{Context}.Adapters.Driven.Persistence.Schemas.{Module}Schema do
  @moduledoc """
  Ecto schema for the {table_name} table.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "{table_name}" do
    # Reference fields as :binary_id (not belongs_to, unless preloading needed)
    field :{fk_field}, :binary_id

    # Regular fields
    field :{field}, :{type}

    timestamps()
  end

  @required_fields ~w({required_field_names})a
  @optional_fields ~w({optional_field_names})a

  def create_changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:{fk_field})
  end
end
```

**Conventions:**
- `@primary_key {:id, :binary_id, autogenerate: true}`
- `@foreign_key_type :binary_id`
- `@timestamps_opts [type: :utc_datetime_usec]`
- Programmatically-set fields (like `user_id`) must NOT be in `cast` — use `put_change` instead
- `@required_fields` and `@optional_fields` as module attributes
- Named changeset functions: `create_changeset/2`, `update_changeset/2`

## Step 6: Generate Mapper

**File:** `lib/klass_hero/{context}/adapters/driven/persistence/mappers/{entity}_mapper.ex`

```elixir
defmodule KlassHero.{Context}.Adapters.Driven.Persistence.Mappers.{Module}Mapper do
  @moduledoc """
  Maps between {Module}Schema (Ecto) and {Module} (domain model).
  """

  alias KlassHero.{Context}.Adapters.Driven.Persistence.Schemas.{Module}Schema
  alias KlassHero.{Context}.Domain.Models.{Module}

  @doc "Converts a {Module}Schema to a domain {Module}."
  @spec to_domain({Module}Schema.t()) :: {Module}.t()
  def to_domain(%{Module}Schema{} = schema) do
    %{Module}{
      id: to_string(schema.id),
      {field_mappings},
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @doc "Converts creation attributes to schema-compatible format."
  @spec to_create_attrs(map()) :: map()
  def to_create_attrs(attrs) when is_map(attrs) do
    attrs
    |> Map.take([{field_atom_list}])
  end
end
```

**Conventions:**
- `to_domain/1` is mandatory — pattern matches on the schema struct
- `to_create_attrs/1` for transforming raw attrs to schema-compatible format
- `@spec` annotations on all public functions
- Binary UUID fields: `to_string(schema.field)` when converting to domain
- Atom/string conversions for enum fields via `String.to_existing_atom`

## Step 7: Generate Port

**File:** `lib/klass_hero/{context}/domain/ports/for_managing_{pluralized}.ex`

```elixir
defmodule KlassHero.{Context}.Domain.Ports.ForManaging{PluralizedPascal} do
  @moduledoc """
  Repository port for managing {pluralized} in the {Context} bounded context.

  This behaviour defines the contract for {entity} persistence.
  Implemented by adapters in the infrastructure layer.
  """

  alias KlassHero.{Context}.Domain.Models.{Module}

  @doc """
  Creates a new {entity}.

  Returns:
  - `{:ok, {Module}.t()}` - {Entity} created
  - `{:error, changeset}` - Validation failure
  """
  @callback create(attrs :: map()) ::
              {:ok, {Module}.t()} | {:error, term()}

  @doc """
  Retrieves a {entity} by ID.

  Returns:
  - `{:ok, {Module}.t()}` - {Entity} found
  - `{:error, :not_found}` - No {entity} exists with the given ID
  """
  @callback get_by_id(id :: binary()) ::
              {:ok, {Module}.t()} | {:error, :not_found}
end
```

**Conventions:**
- `@callback` with full typespecs and `@doc` for each
- Return `{:ok, result}` or `{:error, reason}` tagged tuples
- Port name uses the verb that best fits: `ForStoring*` for simple CRUD, `ForManaging*` for complex

## Step 8: Generate Repository

**File:** `lib/klass_hero/{context}/adapters/driven/persistence/repositories/{entity}_repository.ex`

```elixir
defmodule KlassHero.{Context}.Adapters.Driven.Persistence.Repositories.{Module}Repository do
  @moduledoc """
  Ecto-based repository for managing {pluralized}.

  Implements ForManaging{PluralizedPascal} port.
  """

  @behaviour KlassHero.{Context}.Domain.Ports.ForManaging{PluralizedPascal}

  use KlassHero.Shared.Tracing

  alias KlassHero.{Context}.Adapters.Driven.Persistence.Mappers.{Module}Mapper
  alias KlassHero.{Context}.Adapters.Driven.Persistence.Schemas.{Module}Schema
  alias KlassHero.Repo

  # Add `import Ecto.Query` and `require Logger` when needed by your callbacks

  @impl true
  def create(attrs) do
    span do
      set_attributes("db", operation: "insert", entity: "{entity}")

      schema_attrs = {Module}Mapper.to_create_attrs(attrs)

      %{Module}Schema{}
      |> {Module}Schema.create_changeset(schema_attrs)
      |> Repo.insert()
      |> case do
        {:ok, schema} -> {:ok, {Module}Mapper.to_domain(schema)}
        error -> error
      end
    end
  end

  @impl true
  def get_by_id(id) do
    span do
      set_attributes("db", operation: "select", entity: "{entity}")

      {Module}Schema
      |> Repo.get(id)
      |> case do
        nil -> {:error, :not_found}
        schema -> {:ok, {Module}Mapper.to_domain(schema)}
      end
    end
  end
end
```

**Conventions:**
- `@behaviour` declaration referencing the port
- `use KlassHero.Shared.Tracing` for OpenTelemetry spans
- `@impl true` on every callback
- `span do ... end` with `set_attributes("db", operation: "...", entity: "...")`
- Use mapper for all conversions between schema and domain
- Logger for significant operations

## Step 9: Wire DI Configuration

**File:** `config/config.exs`

Add under the context's config block:
```elixir
config :klass_hero, :{context},
  # ... existing entries ...
  for_managing_{pluralized}:
    KlassHero.{Context}.Adapters.Driven.Persistence.Repositories.{Module}Repository
```

If the context doesn't have a config block yet, create one following existing patterns.

## Step 10: Update Boundary Exports

**File:** `lib/klass_hero/{context}.ex`

Add the domain model to the `exports:` list:
```elixir
use Boundary,
  top_level?: true,
  deps: [...],
  exports: [
    # ... existing exports ...
    Domain.Models.{Module}
  ]
```

## Step 11: Present Summary and Confirm

Before creating any files, present a summary:

```
## Gen-Migration Plan

### Entity: {Module} in {Context}

### Files to create:
1. priv/repo/migrations/{timestamp}_create_{table_name}.exs
2. lib/klass_hero/{context}/domain/models/{entity}.ex
3. lib/klass_hero/{context}/domain/ports/for_managing_{pluralized}.ex
4. lib/klass_hero/{context}/adapters/driven/persistence/schemas/{entity}_schema.ex
5. lib/klass_hero/{context}/adapters/driven/persistence/mappers/{entity}_mapper.ex
6. lib/klass_hero/{context}/adapters/driven/persistence/repositories/{entity}_repository.ex

### Files to modify:
7. config/config.exs — add DI wiring
8. lib/klass_hero/{context}.ex — add Boundary export

### Table: {table_name}
| Column | Type | Constraints |
|--------|------|-------------|
| id | binary_id | primary key |
| ... | ... | ... |
| inserted_at | utc_datetime_usec | not null |
| updated_at | utc_datetime_usec | not null |

### Indexes:
- {index list}
```

**Wait for user confirmation before creating files.**

## Step 12: Generate All Files

Create files in dependency order:
1. Domain model (no dependencies)
2. Port behaviour (depends on domain model)
3. Migration (independent)
4. Schema (independent of domain)
5. Mapper (depends on domain model + schema)
6. Repository (depends on all above)
7. Config update (depends on repository module name)
8. Boundary export update (depends on domain model)

After generation, run:
```bash
mix format
mix compile --warnings-as-errors
```

If compilation fails, diagnose and fix before proceeding.

## Step 13: Run Migration

Ask the user if they want to run the migration now:
```bash
mix ecto.migrate
```

---

## Rules

- **Never generate without confirmation.** Present the full plan in Step 11 first.
- **Read a similar entity in the same context as reference.** Match its patterns exactly.
- **Binary UUIDs everywhere.** All IDs are `:binary_id`, never `:id` or `:integer`.
- **utc_datetime_usec for timestamps.** Both in migration and schema `@timestamps_opts`.
- **primary_key: false on tables.** Manual `:id` field with `:binary_id`.
- **Indexes on all foreign keys.** Every `references()` column gets an explicit index.
- **Domain models are pure.** No Ecto, no infrastructure imports.
- **Mappers are bidirectional.** At minimum `to_domain/1`, preferably also `to_create_attrs/1`.
- **Repositories use Tracing.** `use KlassHero.Shared.Tracing` and `span do` blocks.
- **DI wiring is mandatory.** Every port must have a `config/config.exs` entry.
- **Run `mix compile --warnings-as-errors` after generation.** Zero warnings.
