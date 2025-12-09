defmodule PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepository do
  @moduledoc """
  Repository implementation for listing programs from the database.

  Implements the ForListingPrograms port with:
  - Domain entity mapping via ProgramMapper
  - Comprehensive logging for database operations

  Data integrity is enforced at the database level through NOT NULL constraints.
  """

  @behaviour PrimeYouth.ProgramCatalog.Domain.Ports.ForListingPrograms

  import Ecto.Query

  alias PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Mappers.ProgramMapper
  alias PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
  alias PrimeYouth.ProgramCatalog.Domain.Models.Program
  alias PrimeYouth.Repo
  alias PrimeYouthWeb.ErrorIds

  require Logger

  @impl true
  @doc """
  Lists all programs from the database.

  Programs are ordered by title in ascending order for consistent display.
  Data integrity is enforced at the database level through NOT NULL constraints
  on all required fields (title, description, schedule, age_range, price, pricing_period).

  Returns:
  - {:ok, [Program.t()]} on success (empty list if no programs exist)
  - {:error, :database_connection_error} - Connection/network failure
  - {:error, :database_query_error} - SQL error or constraint violation
  - {:error, :database_unavailable} - Unexpected error

  ## Examples

      iex> ProgramRepository.list_all_programs()
      {:ok, [%Program{title: "Art Adventures", ...}, %Program{title: "Soccer Camp", ...}]}

      iex> ProgramRepository.list_all_programs()
      {:ok, []}  # No programs in database

      iex> ProgramRepository.list_all_programs()
      {:error, :database_connection_error}  # Database connection failed

      iex> ProgramRepository.list_all_programs()
      {:error, :database_query_error}  # SQL syntax error

  """
  @spec list_all_programs() ::
          {:ok, [Program.t()]}
          | {:error, :database_connection_error | :database_query_error | :database_unavailable}
  def list_all_programs do
    Logger.info("[ProgramRepository] Starting list_all_programs query")

    query = from p in ProgramSchema, order_by: [asc: p.title]

    try do
      schemas = Repo.all(query)
      programs = ProgramMapper.to_domain_list(schemas)

      Logger.info(
        "[ProgramRepository] Successfully retrieved #{length(programs)} programs from database"
      )

      {:ok, programs}
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[ProgramRepository] Database connection failed",
          error_id: ErrorIds.program_list_connection_error(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[ProgramRepository] Database query error",
          error_id: ErrorIds.program_list_query_error(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[ProgramRepository] Unexpected database error",
          error_id: ErrorIds.program_list_generic_error(),
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  @doc """
  Retrieves a single program by its unique ID (UUID) from the database.

  Data integrity is enforced at the database level through NOT NULL constraints
  on all required fields.

  Returns:
  - {:ok, Program.t()} when program is found
  - {:error, :not_found} when no program exists with the given ID
  - {:error, :database_connection_error} - Connection/network failure
  - {:error, :database_query_error} - SQL error or constraint violation
  - {:error, :database_unavailable} - Unexpected error

  ## Examples

      iex> ProgramRepository.get_by_id("550e8400-e29b-41d4-a716-446655440001")
      {:ok, %Program{id: "550e8400-e29b-41d4-a716-446655440001", title: "Art Adventures", ...}}

      iex> ProgramRepository.get_by_id("550e8400-e29b-41d4-a716-446655440099")
      {:error, :not_found}

      iex> ProgramRepository.get_by_id("invalid-uuid")
      {:error, :database_query_error}  # Invalid UUID format

  """
  @spec get_by_id(String.t()) ::
          {:ok, Program.t()}
          | {:error,
             :not_found
             | :database_connection_error
             | :database_query_error
             | :database_unavailable}
  def get_by_id(id) when is_binary(id) do
    Logger.info("[ProgramRepository] Starting get_by_id query for program ID: #{id}")

    query = from p in ProgramSchema, where: p.id == ^id

    try do
      case Repo.one(query) do
        nil ->
          Logger.info("[ProgramRepository] Program not found with ID: #{id}")
          {:error, :not_found}

        schema ->
          program = ProgramMapper.to_domain(schema)

          Logger.info(
            "[ProgramRepository] Successfully retrieved program '#{program.title}' (ID: #{id}) from database"
          )

          {:ok, program}
      end
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[ProgramRepository] Database connection failed while fetching program ID: #{id}",
          error_id: ErrorIds.program_get_connection_error(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[ProgramRepository] Database query error while fetching program ID: #{id}",
          error_id: ErrorIds.program_get_query_error(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[ProgramRepository] Unexpected database error while fetching program ID: #{id}",
          error_id: ErrorIds.program_get_generic_error(),
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end
end
