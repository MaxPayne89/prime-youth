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
end
