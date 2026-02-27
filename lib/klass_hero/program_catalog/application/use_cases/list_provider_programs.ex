defmodule KlassHero.ProgramCatalog.Application.UseCases.ListProviderPrograms do
  @moduledoc """
  Use case for listing programs belonging to a specific provider.

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

      programs = ListProviderPrograms.execute(provider_id)
  """

  alias KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListing

  @read_repository Application.compile_env!(
                     :klass_hero,
                     [:program_catalog, :for_listing_program_summaries]
                   )

  @doc """
  Executes the use case to list programs for a specific provider.

  Retrieves all program listings belonging to the given provider from the
  read model. Listings are returned in ascending order by title.

  Returns:
  - `[ProgramListing.t()]` - List of provider's program listings (may be empty)

  ## Examples

      # Successful retrieval
      programs = ListProviderPrograms.execute("provider-uuid")
      Enum.each(programs, fn program ->
        IO.puts(program.title)
      end)

      # Provider with no programs
      [] = ListProviderPrograms.execute("new-provider-uuid")
  """
  @spec execute(String.t()) :: [ProgramListing.t()]
  def execute(provider_id) when is_binary(provider_id) do
    @read_repository.list_for_provider(provider_id)
  end
end
