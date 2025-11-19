defmodule PrimeYouth.ProgramCatalog.Application.UseCases.ListAllPrograms do
  @moduledoc """
  Use case for listing all available programs from the Program Catalog.

  This use case orchestrates the retrieval of all valid programs from the repository.
  It delegates to the repository port and returns the result without additional processing.

  ## Architecture

  This use case follows the Application Layer pattern in DDD/Ports & Adapters:
  - Coordinates domain operations (via repository port)
  - No business logic (that belongs in domain layer)
  - No logging (that belongs in adapter layer)
  - Returns domain entities (Program structs)

  ## Dependency Injection

  The repository implementation is configured via Application config:

      config :prime_youth, :program_catalog,
        repository: PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepository

  ## Usage

      {:ok, programs} = ListAllPrograms.execute()
      {:error, :database_connection_error} = ListAllPrograms.execute()
      {:error, :database_query_error} = ListAllPrograms.execute()
      {:error, :database_unavailable} = ListAllPrograms.execute()
  """

  alias PrimeYouth.ProgramCatalog.Domain.Models.Program
  alias PrimeYouth.ProgramCatalog.Domain.Ports.ForListingPrograms

  @doc """
  Executes the use case to list all available programs.

  Retrieves all programs from the repository that have complete data
  (all required fields populated). Programs are returned in ascending
  order by title.

  Returns:
  - `{:ok, [Program.t()]}` - List of valid programs (may be empty)
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      # Successful retrieval
      {:ok, programs} = ListAllPrograms.execute()
      Enum.each(programs, fn program ->
        IO.puts(program.title)
      end)

      # Empty database
      {:ok, []} = ListAllPrograms.execute()

      # Database errors
      {:error, :database_connection_error} = ListAllPrograms.execute()
      {:error, :database_query_error} = ListAllPrograms.execute()
      {:error, :database_unavailable} = ListAllPrograms.execute()
  """
  @spec execute() :: {:ok, [Program.t()]} | {:error, ForListingPrograms.list_error()}
  def execute do
    repository_module().list_all_programs()
  end

  # Private helper to get the configured repository module
  defp repository_module do
    Application.get_env(:prime_youth, :program_catalog)[:repository]
  end
end
