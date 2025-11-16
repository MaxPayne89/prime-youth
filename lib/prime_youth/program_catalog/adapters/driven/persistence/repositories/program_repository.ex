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

  require Logger

  @impl true
  @doc """
  Lists all programs from the database.

  Programs are ordered by title in ascending order for consistent display.
  Data integrity is enforced at the database level through NOT NULL constraints
  on all required fields (title, description, schedule, age_range, price, pricing_period).

  Returns:
  - {:ok, [Program.t()]} on success (empty list if no programs exist)
  - {:error, :database_unavailable} if database query fails

  ## Examples

      iex> ProgramRepository.list_all_programs()
      {:ok, [%Program{title: "Art Adventures", ...}, %Program{title: "Soccer Camp", ...}]}

      iex> ProgramRepository.list_all_programs()
      {:ok, []}  # No programs in database

      iex> ProgramRepository.list_all_programs()
      {:error, :database_unavailable}  # Database connection failed

  """
  @spec list_all_programs() :: {:ok, [Program.t()]} | {:error, :database_unavailable}
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
      error ->
        Logger.error(
          "[ProgramRepository] Failed to retrieve programs: #{inspect(error)}"
        )

        {:error, :database_unavailable}
    end
  end
end
