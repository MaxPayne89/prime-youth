defmodule PrimeYouth.ProgramCatalog.Domain.Ports.ProgramRepository do
  @moduledoc """
  Repository port (behavior) for Program entity operations.

  This defines the contract for program persistence without specifying implementation details.
  Follows the Ports & Adapters (Hexagonal) architecture pattern, allowing the domain layer
  to remain independent of infrastructure concerns.

  ## Implementation

  The actual implementation is provided by:
  - `PrimeYouth.ProgramCatalog.Adapters.Ecto.ProgramRepository` (Ecto/PostgreSQL adapter)

  Configuration in `config.exs`:
  ```elixir
  config :prime_youth, :program_repository,
    PrimeYouth.ProgramCatalog.Adapters.Ecto.ProgramRepository
  ```

  ## Usage in Use Cases

  Use cases inject the repository via configuration:

  ```elixir
  @program_repo Application.compile_env(
    :prime_youth,
    :program_repository,
    PrimeYouth.ProgramCatalog.Adapters.Ecto.ProgramRepository
  )

  def execute(filters) do
    programs = @program_repo.list(filters)
    # ... use case logic
  end
  ```
  """

  alias PrimeYouth.ProgramCatalog.Domain.Entities.Program

  @doc """
  Retrieves a program by its unique identifier.

  Preloads all associations (schedules, locations, provider) for complete program data.

  ## Parameters

  - `id`: Program UUID (string)

  ## Returns

  - `{:ok, %Program{}}` if found
  - `{:error, :not_found}` if program doesn't exist

  ## Examples

      iex> get("valid-uuid")
      {:ok, %Program{id: "valid-uuid", title: "Summer Camp", ...}}

      iex> get("invalid-uuid")
      {:error, :not_found}

  """
  @callback get(id :: String.t()) :: {:ok, Program.t()} | {:error, :not_found}

  @doc """
  Lists programs with optional filtering.

  Supports filtering by multiple criteria, preloads associations, and returns only
  approved programs by default (unless status filter is explicitly provided).

  ## Filter Options

  - `:category` - Filter by primary category (ProgramCategory value)
  - `:age_min`, `:age_max` - Filter by age range overlap
  - `:city` - Filter by location city
  - `:state` - Filter by location state
  - `:price_min`, `:price_max` - Filter by price range
  - `:is_prime_youth` - Filter by provider type (boolean)
  - `:status` - Filter by approval status (defaults to "approved")
  - `:featured` - Filter featured programs only (boolean)
  - `:provider_id` - Filter by specific provider

  ## Returns

  - List of `%Program{}` structs matching the filters

  ## Examples

      iex> list(%{category: "sports", age_min: 5, age_max: 10})
      [%Program{category: "sports", age_range: %{min: 5, max: 12}}, ...]

      iex> list(%{city: "Chicago", is_prime_youth: true})
      [%Program{locations: [%{city: "Chicago"}]}, ...]

      iex> list(%{})
      [%Program{status: "approved"}, ...]  # Only approved programs by default

  """
  @callback list(filters :: map()) :: [Program.t()]

  @doc """
  Searches programs by keyword with full-text search.

  Uses PostgreSQL full-text search (to_tsvector) with trigram similarity for fuzzy matching.
  Searches in program title and description fields. Can be combined with filters.

  ## Parameters

  - `query`: Search keyword or phrase (string)
  - `filters`: Optional filters (same as `list/1`)

  ## Returns

  - List of `%Program{}` structs matching search query and filters
  - Results sorted by relevance (exact matches first, then fuzzy matches)

  ## Examples

      iex> search("soccer", %{})
      [%Program{title: "Soccer Camp"}, %Program{description: "...soccer skills..."}, ...]

      iex> search("soccr", %{})  # Fuzzy match
      [%Program{title: "Soccer Camp"}, ...]

      iex> search("stem", %{age_min: 8, age_max: 12})
      [%Program{title: "STEM Workshop", age_range: %{min: 8, max: 14}}, ...]

  """
  @callback search(query :: String.t(), filters :: map()) :: [Program.t()]

  @doc """
  Creates a new program.

  Validates program attributes, creates associated schedules and locations,
  and sets appropriate default status based on provider type.

  ## Parameters

  - `attrs`: Map of program attributes (including nested schedules and locations)

  ## Returns

  - `{:ok, %Program{}}` if created successfully
  - `{:error, %Ecto.Changeset{}}` if validation fails

  ## Examples

      iex> create(%{
      ...>   title: "Summer Camp",
      ...>   description: "Fun camp",
      ...>   provider_id: "provider-uuid",
      ...>   category: "sports",
      ...>   age_min: 5,
      ...>   age_max: 10,
      ...>   capacity: 20,
      ...>   price_amount: 200,
      ...>   schedules: [%{...}],
      ...>   locations: [%{...}]
      ...> })
      {:ok, %Program{}}

  """
  @callback create(attrs :: map()) :: {:ok, Program.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates an existing program.

  Validates changes and updates program attributes. Archived programs cannot be updated.

  ## Parameters

  - `program`: Existing program struct
  - `attrs`: Map of attributes to update

  ## Returns

  - `{:ok, %Program{}}` if updated successfully
  - `{:error, %Ecto.Changeset{}}` if validation fails or program is archived

  ## Examples

      iex> update(program, %{title: "Updated Title"})
      {:ok, %Program{title: "Updated Title"}}

      iex> update(archived_program, %{title: "New Title"})
      {:error, %Ecto.Changeset{}}  # Cannot update archived programs

  """
  @callback update(program :: Program.t(), attrs :: map()) ::
              {:ok, Program.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Soft deletes a program by setting archived_at timestamp.

  Archived programs are not visible in marketplace but remain in database for historical records.

  ## Parameters

  - `program`: Program struct to archive

  ## Returns

  - `{:ok, %Program{}}` with `archived_at` set
  - `{:error, %Ecto.Changeset{}}` if deletion fails

  ## Examples

      iex> delete(program)
      {:ok, %Program{archived_at: ~U[2025-11-02 12:00:00Z]}}

  """
  @callback delete(program :: Program.t()) :: {:ok, Program.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Lists all programs for a specific provider.

  Returns all programs (regardless of status) for provider dashboard view.

  ## Parameters

  - `provider_id`: Provider UUID (string)

  ## Returns

  - List of `%Program{}` structs belonging to the provider

  ## Examples

      iex> list_by_provider("provider-uuid")
      [%Program{provider_id: "provider-uuid", status: "draft"}, ...]

  """
  @callback list_by_provider(provider_id :: String.t()) :: [Program.t()]

  @doc """
  Lists all programs pending approval.

  Used by admin dashboard to show programs awaiting review.

  ## Returns

  - List of `%Program{}` structs with status "pending_approval"

  ## Examples

      iex> list_pending_approval()
      [%Program{status: "pending_approval", title: "..."}, ...]

  """
  @callback list_pending_approval() :: [Program.t()]

  @doc """
  Approves a program and updates its status.

  Changes program status from "pending_approval" to "approved" and broadcasts
  PubSub notification to provider.

  ## Parameters

  - `program_id`: Program UUID (string)
  - `admin_id`: Admin user UUID performing approval (string)

  ## Returns

  - `{:ok, %Program{}}` with updated status
  - `{:error, reason}` if approval fails (invalid state, not found, etc.)

  ## Examples

      iex> approve("program-uuid", "admin-uuid")
      {:ok, %Program{status: "approved"}}

      iex> approve("already-approved", "admin-uuid")
      {:error, :invalid_state_transition}

  """
  @callback approve(program_id :: String.t(), admin_id :: String.t()) ::
              {:ok, Program.t()} | {:error, term()}

  @doc """
  Rejects a program with reason and updates its status.

  Changes program status from "pending_approval" to "rejected", stores rejection reason,
  and broadcasts PubSub notification to provider.

  ## Parameters

  - `program_id`: Program UUID (string)
  - `admin_id`: Admin user UUID performing rejection (string)
  - `reason`: Explanation for rejection (string)

  ## Returns

  - `{:ok, %Program{}}` with updated status and rejection reason
  - `{:error, reason}` if rejection fails (invalid state, not found, etc.)

  ## Examples

      iex> reject("program-uuid", "admin-uuid", "Insufficient details")
      {:ok, %Program{status: "rejected", rejection_reason: "Insufficient details"}}

      iex> reject("approved-program", "admin-uuid", "reason")
      {:error, :invalid_state_transition}

  """
  @callback reject(program_id :: String.t(), admin_id :: String.t(), reason :: String.t()) ::
              {:ok, Program.t()} | {:error, term()}
end
