defmodule KlassHero.ProgramCatalog.Application.UseCases.ListFeaturedPrograms do
  @moduledoc """
  Use case for listing featured programs from the Program Catalog.

  Reads from the denormalized program_listings read model (CQRS read side).
  Retrieves the first 2 programs ordered by title to be displayed as
  featured programs on the home page.

  ## Architecture

  This use case follows the Application Layer pattern in DDD/Ports & Adapters:
  - Coordinates domain operations (via read repository port)
  - Simple post-processing (limiting to first 2 programs)
  - No logging (that belongs in adapter layer)
  - Returns read model DTOs (ProgramListing structs)

  ## Dependency Injection

  The repository implementation is configured via Application config:

      config :klass_hero, :program_catalog,
        for_listing_program_summaries: KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramListingsRepository

  ## Usage

      featured = ListFeaturedPrograms.execute()
      # Returns first 2 programs ordered by title

      [] = ListFeaturedPrograms.execute()
      # Returns empty list if no programs exist
  """

  alias KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListing

  @featured_count 2

  @doc """
  Executes the use case to list featured programs.

  Retrieves all program listings from the read model and returns the
  first #{@featured_count} ordered by title. This provides a consistent
  set of featured programs for the home page.

  Returns:
  - `[ProgramListing.t()]` - List of featured program listings (up to #{@featured_count}, may be empty)

  ## Examples

      # Successful retrieval with multiple programs
      [program1, program2] = ListFeaturedPrograms.execute()

      # Database has only 1 program
      [program1] = ListFeaturedPrograms.execute()

      # Empty database
      [] = ListFeaturedPrograms.execute()
  """
  @spec execute() :: [ProgramListing.t()]
  def execute do
    read_repository().list_all()
    |> Enum.take(@featured_count)
  end

  defp read_repository do
    Application.get_env(:klass_hero, :program_catalog)[:for_listing_program_summaries]
  end
end
