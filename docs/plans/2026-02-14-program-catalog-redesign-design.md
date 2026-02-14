# Program Catalog Bounded Context Redesign

## Problem

The ProgramCatalog aggregate root (`Program`) is anemic. Use cases bypass the domain model — raw attrs go straight to the repository. The `Instructor` value object's validation is never used during creation. No update use case exists despite the port being defined.

## Approach: Aggregate Factory

Add factory/mutation methods on the `Program` aggregate. Use cases orchestrate through the domain model before persisting. Ports become type-safe.

## Validation Split

- **Domain model**: business invariants (semantic rules — valid category, non-empty title, instructor consistency)
- **Ecto changeset**: structural validation (types, lengths, constraints) — defense-in-depth
- **Use case**: orchestrates both — domain validates first, then persists

## Changes

### 1. Program Aggregate

Add `create/1` and `apply_changes/2`:

```elixir
# Factory for new programs — validates business invariants
@spec create(map()) :: {:ok, t()} | {:error, [String.t()]}
def create(attrs) do
  with {:ok, instructor} <- build_instructor(attrs),
       base <- build_base(attrs, instructor),
       :ok <- validate_invariants(base) do
    {:ok, base}
  end
end

# Mutation for updates — merges changes, re-validates
@spec apply_changes(t(), map()) :: {:ok, t()} | {:error, [String.t()]}
def apply_changes(%__MODULE__{} = program, changes) do
  with {:ok, instructor} <- maybe_update_instructor(program, changes),
       updated <- merge_changes(program, changes, instructor),
       :ok <- validate_invariants(updated) do
    {:ok, updated}
  end
end
```

Remove `:id` from `@enforce_keys` — ID comes from DB on insert.

`new/1` stays for trusted reconstitution from persistence.

Invariants enforced:
- title: non-empty string
- description: non-empty string
- category: valid via `ProgramCategories.valid_program_category?/1`
- price: Decimal >= 0
- spots_available: integer >= 0
- provider_id: required for creation
- instructor: if data present, validated via `Instructor.new/1`

### 2. CreateProgram Use Case

```elixir
def execute(attrs) when is_map(attrs) do
  with {:ok, program} <- Program.create(attrs),
       {:ok, persisted} <- @repository.create(program) do
    dispatch_event(persisted)
    {:ok, persisted}
  end
end
```

No UUID generation — DB assigns via Ecto autogenerate.

### 3. UpdateProgram Use Case (new)

```elixir
def execute(id, changes) when is_binary(id) and is_map(changes) do
  with {:ok, program} <- @repository.get_by_id(id),
       {:ok, updated} <- Program.apply_changes(program, changes),
       {:ok, persisted} <- @repository.update(updated) do
    {:ok, persisted}
  end
end
```

Optimistic locking via lock_version on loaded aggregate.

### 4. Port Contracts

```elixir
# ForCreatingPrograms — takes validated domain struct
@callback create(program :: Program.t()) ::
  {:ok, Program.t()} | {:error, Ecto.Changeset.t()}

# ForUpdatingPrograms — formalize type
@callback update(program :: Program.t()) ::
  {:ok, Program.t()} | {:error, :stale_data | :not_found | Ecto.Changeset.t()}
```

### 5. Repository

`create/1` receives `%Program{}`, converts via mapper:

```elixir
def create(%Program{} = program) do
  attrs = ProgramMapper.to_schema(program)
  %ProgramSchema{}
  |> ProgramSchema.create_changeset(attrs)
  |> Repo.insert()
  |> case do
    {:ok, schema} -> {:ok, ProgramMapper.to_domain(schema)}
    {:error, changeset} -> {:error, changeset}
  end
end
```

### 6. Mapper

`to_schema/1` extended to include `provider_id`.

### 7. Facade

Add `update_program/2` delegating to `UpdateProgram.execute/2`.

## Not Changing

- Query use cases (thin delegations — CQRS-lite)
- Domain services (ProgramCategories, ProgramFilter, ProgramPricing, TrendingSearches)
- Event system (domain + integration events)
- Mapper read path (to_domain/1)
- Web layer (public API stays the same)
- Ecto schema changesets (defense-in-depth)
