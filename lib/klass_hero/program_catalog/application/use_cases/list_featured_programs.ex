defmodule KlassHero.ProgramCatalog.Application.UseCases.ListFeaturedPrograms do
  @moduledoc """
  Use case for listing featured programs from the Program Catalog.

  This use case retrieves the first 2 programs from the repository to be displayed
  as featured programs on the home page. Programs are ordered by title.

  ## Architecture

  This use case follows the Application Layer pattern in DDD/Ports & Adapters:
  - Coordinates domain operations (via repository port)
  - Simple post-processing (limiting to first 2 programs)
  - No logging (that belongs in adapter layer)
  - Returns domain entities (Program structs)

  ## Dependency Injection

  The repository implementation is configured via Application config:

      config :klass_hero, :program_catalog,
        repository: KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepository

  ## Usage

      featured = ListFeaturedPrograms.execute()
      # Returns first 2 programs ordered by title

      [] = ListFeaturedPrograms.execute()
      # Returns empty list if no programs exist
  """

  alias KlassHero.ProgramCatalog.Domain.Models.Program

  @featured_count 2

  @doc """
  Executes the use case to list featured programs.

  Retrieves all programs from the repository and returns the first #{@featured_count}
  programs ordered by title. This provides a consistent set of featured programs
  for the home page.

  Returns:
  - `[Program.t()]` - List of featured programs (up to #{@featured_count}, may be empty)

  ## Examples

      # Successful retrieval with multiple programs
      [program1, program2] = ListFeaturedPrograms.execute()

      # Database has only 1 program
      [program1] = ListFeaturedPrograms.execute()

      # Empty database
      [] = ListFeaturedPrograms.execute()
  """
  @spec execute() :: [Program.t()]
  def execute do
    repository_module().list_all_programs()
    |> Enum.take(@featured_count)
  end

  # Private helper to get the configured repository module
  defp repository_module do
    Application.get_env(:klass_hero, :program_catalog)[:repository]
  end
end
