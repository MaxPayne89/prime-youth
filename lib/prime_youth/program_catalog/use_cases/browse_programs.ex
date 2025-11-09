defmodule PrimeYouth.ProgramCatalog.UseCases.BrowsePrograms do
  @moduledoc """
  Use case for browsing and discovering programs in the marketplace.

  This use case orchestrates the program discovery flow, handling filtering,
  searching, and pagination of available programs.

  ## Responsibilities

  - List programs with optional filtering (category, age, location, price)
  - Full-text search across program titles and descriptions
  - Apply marketplace visibility rules (approved, not archived)
  - Sort and paginate results for optimal UX

  ## Usage

      # List all programs
      BrowsePrograms.execute()

      # Filter by category
      BrowsePrograms.execute(%{category: "sports"})

      # Search with filters
      BrowsePrograms.search("soccer", %{age_min: 10, age_max: 12})

      # Filter by location
      BrowsePrograms.execute(%{city: "San Francisco", state: "CA"})

      # Filter by price range
      BrowsePrograms.execute(%{price_min: 0, price_max: 500})
  """

  require Logger

  @doc """
  Execute the browse programs use case with optional filters.

  Returns `{:ok, programs}` with a list of programs matching the provided filters.
  Only returns programs that are visible in the marketplace (approved, not archived).

  ## Filters

  - `:category` - Filter by primary category
  - `:age_min` - Minimum age (finds programs where age_max >= age_min)
  - `:age_max` - Maximum age (finds programs where age_min <= age_max)
  - `:city` - Filter by program location city (case-insensitive partial match)
  - `:state` - Filter by program location state (case-insensitive partial match)
  - `:price_min` - Minimum price in cents
  - `:price_max` - Maximum price in cents
  - `:is_prime_youth` - Filter Prime Youth programs (true/false)
  - `:featured` - Filter featured programs (true/false)
  - `:provider_id` - Filter by provider ID

  ## Examples

      iex> BrowsePrograms.execute()
      {:ok, [%Program{}, ...]}

      iex> BrowsePrograms.execute(%{category: "sports", age_min: 10, age_max: 12})
      {:ok, [%Program{}, ...]}

      iex> BrowsePrograms.execute(%{city: "San Francisco", price_max: 500})
      {:ok, [%Program{}, ...]}
  """
  def execute(filters \\ %{}) do
    Logger.info("Listing programs with filters: #{inspect(Map.keys(filters))}")

    repo = get_repository()

    # Repository automatically filters for approved, non-archived programs
    programs = repo.list(filters)

    Logger.info(
      "Programs retrieved successfully: count=#{length(programs)}, filters=#{inspect(Map.keys(filters))}"
    )

    {:ok, programs}
  end

  @doc """
  Search programs by query text with optional filters.

  Performs full-text search across program titles and descriptions using
  PostgreSQL's text search capabilities with fuzzy matching.

  ## Parameters

  - `query` - Search query string (required)
  - `filters` - Optional filters (same as execute/1)

  ## Examples

      iex> BrowsePrograms.search("soccer")
      [%Program{}, ...]

      iex> BrowsePrograms.search("basketball", %{age_min: 10, city: "Oakland"})
      [%Program{}, ...]
  """
  def search(query, filters \\ %{}) when is_binary(query) do
    Logger.info(
      "Searching programs: query=#{query}, length=#{String.length(query)}, filters=#{inspect(Map.keys(filters))}"
    )

    repo = get_repository()
    programs = repo.search(query, filters)

    Logger.info(
      "Search completed successfully: query=#{query}, results=#{length(programs)}, filters=#{inspect(Map.keys(filters))}"
    )

    programs
  end

  @doc """
  Get a single program by ID.

  Returns `{:ok, program}` if found, `{:error, :not_found}` if not found.

  ## Examples

      iex> BrowsePrograms.get_program("program-id-123")
      {:ok, %Program{}}

      iex> BrowsePrograms.get_program("nonexistent")
      {:error, :not_found}
  """
  def get_program(program_id) when is_binary(program_id) do
    Logger.info("Fetching program by ID: #{program_id}")

    repo = get_repository()
    result = repo.get(program_id)

    case result do
      {:ok, program} ->
        Logger.info(
          "Program retrieved successfully: id=#{program_id}, title=#{program.title}, category=#{program.category}"
        )

      {:error, :not_found} ->
        Logger.warning("Program not found: #{program_id}")
    end

    result
  end

  @doc """
  List programs by provider ID.

  Returns all approved, non-archived programs for a specific provider.

  ## Examples

      iex> BrowsePrograms.list_by_provider("provider-id-123")
      [%Program{}, ...]
  """
  def list_by_provider(provider_id) when is_binary(provider_id) do
    Logger.info("Listing programs for provider: #{provider_id}")

    repo = get_repository()
    programs = repo.list_by_provider(provider_id)

    Logger.info(
      "Provider programs retrieved successfully: provider=#{provider_id}, count=#{length(programs)}"
    )

    programs
  end

  # Private helper to get repository implementation from config
  defp get_repository do
    Application.get_env(
      :prime_youth,
      :program_repository,
      PrimeYouth.ProgramCatalog.Adapters.Ecto.ProgramRepository
    )
  end
end
