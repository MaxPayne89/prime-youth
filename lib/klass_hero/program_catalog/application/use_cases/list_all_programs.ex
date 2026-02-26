defmodule KlassHero.ProgramCatalog.Application.UseCases.ListAllPrograms do
  @moduledoc """
  Use case for listing all available programs from the Program Catalog.

  Reads from the denormalized program_listings read model (CQRS read side),
  returning lightweight ProgramListing DTOs instead of full domain entities.

  ## Architecture

  This use case follows the Application Layer pattern in DDD/Ports & Adapters:
  - Coordinates domain operations (via read repository port)
  - No business logic (that belongs in domain layer)
  - No logging (that belongs in adapter layer)
  - Returns read model DTOs (ProgramListing structs)

  ## Dependency Injection

  The repository implementation is configured via Application config:

      config :klass_hero, :program_catalog,
        for_listing_program_summaries: KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramListingsRepository

  ## Usage

      programs = ListAllPrograms.execute()
  """

  alias KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListing

  @doc """
  Executes the use case to list all available programs.

  Retrieves all program listings from the read model, ordered by title.

  Returns:
  - `[ProgramListing.t()]` - List of program listings (may be empty)

  ## Examples

      # Successful retrieval
      programs = ListAllPrograms.execute()
      Enum.each(programs, fn program ->
        IO.puts(program.title)
      end)

      # Empty database
      [] = ListAllPrograms.execute()
  """
  @spec execute() :: [ProgramListing.t()]
  def execute do
    read_repository().list_all()
  end

  defp read_repository do
    Application.get_env(:klass_hero, :program_catalog)[:for_listing_program_summaries]
  end
end
