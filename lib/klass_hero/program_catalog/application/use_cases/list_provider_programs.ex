defmodule KlassHero.ProgramCatalog.Application.UseCases.ListProviderPrograms do
  @moduledoc """
  Use case for listing programs belonging to a specific provider.

  This use case orchestrates the retrieval of programs for a provider from the repository.
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

      programs = ListProviderPrograms.execute(provider_id)
  """

  alias KlassHero.ProgramCatalog.Domain.Models.Program

  @doc """
  Executes the use case to list programs for a specific provider.

  Retrieves all programs belonging to the given provider from the repository.
  Programs are returned in ascending order by title.

  Returns:
  - `[Program.t()]` - List of provider's programs (may be empty)

  ## Examples

      # Successful retrieval
      programs = ListProviderPrograms.execute("provider-uuid")
      Enum.each(programs, fn program ->
        IO.puts(program.title)
      end)

      # Provider with no programs
      [] = ListProviderPrograms.execute("new-provider-uuid")
  """
  @spec execute(String.t()) :: [Program.t()]
  def execute(provider_id) when is_binary(provider_id) do
    repository_module().list_programs_for_provider(provider_id)
  end

  defp repository_module do
    Application.get_env(:klass_hero, :program_catalog)[:repository]
  end
end
