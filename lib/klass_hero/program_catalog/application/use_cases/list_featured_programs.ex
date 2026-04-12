defmodule KlassHero.ProgramCatalog.Application.UseCases.ListFeaturedPrograms do
  @moduledoc """
  Use case for listing featured programs from the Program Catalog.

  Reads from the denormalized program_listings read model (CQRS read side).
  Retrieves the first 2 non-expired programs ordered by title to be displayed
  as featured programs on the home page. Programs whose `end_date` has passed
  are filtered out; programs with a nil `end_date` are treated as open-ended
  and remain eligible (see issue #610).

  ## Architecture

  This use case follows the Application Layer pattern in DDD/Ports & Adapters:
  - Coordinates domain operations (via read repository port)
  - Delegates the LIMIT to SQL via `list_active_limited/1` to avoid over-fetching
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

  @read_repository Application.compile_env!(
                     :klass_hero,
                     [:program_catalog, :for_listing_program_summaries]
                   )

  @featured_count 2

  @doc """
  Executes the use case to list featured programs.

  Retrieves at most #{@featured_count} active program listings from the read model
  using a SQL `LIMIT` clause, ordered by title ascending. Programs whose `end_date`
  has passed are excluded; programs with a nil `end_date` are treated as open-ended.
  This provides a consistent set of featured programs for the home page (see issue #610).

  Returns:
  - `[ProgramListing.t()]` - List of featured program listings (up to #{@featured_count}, may be empty)

  ## Examples

      # Successful retrieval with multiple active programs
      [program1, program2] = ListFeaturedPrograms.execute()

      # Database has only 1 active program
      [program1] = ListFeaturedPrograms.execute()

      # Empty database or all programs expired
      [] = ListFeaturedPrograms.execute()
  """
  @spec execute() :: [ProgramListing.t()]
  def execute do
    @read_repository.list_active_limited(@featured_count)
  end
end
