defmodule KlassHero.ProgramCatalog.Application.UseCases.ListAllPrograms do
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

      config :klass_hero, :program_catalog,
        repository: KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepository

  ## Usage

      programs = ListAllPrograms.execute()
  """

  alias KlassHero.ProgramCatalog.Domain.Models.Program

  @doc """
  Executes the use case to list all available programs.

  Retrieves all programs from the repository that have complete data
  (all required fields populated). Programs are returned in ascending
  order by title.

  Returns:
  - `[Program.t()]` - List of valid programs (may be empty)

  ## Examples

      # Successful retrieval
      programs = ListAllPrograms.execute()
      Enum.each(programs, fn program ->
        IO.puts(program.title)
      end)

      # Empty database
      [] = ListAllPrograms.execute()
  """
  @spec execute() :: [Program.t()]
  def execute do
    repository_module().list_all_programs()
  end

  # Private helper to get the configured repository module
  defp repository_module do
    Application.get_env(:klass_hero, :program_catalog)[:repository]
  end
end
