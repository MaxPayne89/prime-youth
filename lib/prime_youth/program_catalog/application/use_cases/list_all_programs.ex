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
      {:error, :database_error} = ListAllPrograms.execute()
  """

  alias PrimeYouth.ProgramCatalog.Domain.Models.Program

  @doc """
  Executes the use case to list all available programs.

  Retrieves all programs from the repository that have complete data
  (all required fields populated). Programs are returned in ascending
  order by title.

  Returns:
  - `{:ok, [Program.t()]}` - List of valid programs (may be empty)
  - `{:error, :database_error}` - Database connection or query failure

  ## Examples

      # Successful retrieval
      {:ok, programs} = ListAllPrograms.execute()
      Enum.each(programs, fn program ->
        IO.puts(program.title)
      end)

      # Empty database
      {:ok, []} = ListAllPrograms.execute()

      # Database error
      {:error, :database_error} = ListAllPrograms.execute()
  """
  @spec execute() :: {:ok, [Program.t()]} | {:error, :database_error}
  def execute do
    repository_module().list_all_programs()
  end

  # Private helper to get the configured repository module
  defp repository_module do
    Application.get_env(:prime_youth, :program_catalog)[:repository]
  end
end
