defmodule PrimeYouth.ProgramCatalog.Application.UseCases.ListFeaturedPrograms do
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

      config :prime_youth, :program_catalog,
        repository: PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepository

  ## Usage

      {:ok, featured} = ListFeaturedPrograms.execute()
      # Returns first 2 programs ordered by title

      {:ok, []} = ListFeaturedPrograms.execute()
      # Returns empty list if no programs exist

      {:error, :database_connection_error} = ListFeaturedPrograms.execute()
  """

  alias PrimeYouth.ProgramCatalog.Domain.Models.Program
  alias PrimeYouth.ProgramCatalog.Domain.Ports.ForListingPrograms

  @featured_count 2

  @doc """
  Executes the use case to list featured programs.

  Retrieves all programs from the repository and returns the first #{@featured_count}
  programs ordered by title. This provides a consistent set of featured programs
  for the home page.

  Returns:
  - `{:ok, [Program.t()]}` - List of featured programs (up to #{@featured_count}, may be empty)
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      # Successful retrieval with multiple programs
      {:ok, [program1, program2]} = ListFeaturedPrograms.execute()

      # Database has only 1 program
      {:ok, [program1]} = ListFeaturedPrograms.execute()

      # Empty database
      {:ok, []} = ListFeaturedPrograms.execute()

      # Database errors
      {:error, :database_connection_error} = ListFeaturedPrograms.execute()
  """
  @spec execute() :: {:ok, [Program.t()]} | {:error, ForListingPrograms.list_error()}
  def execute do
    case repository_module().list_all_programs() do
      {:ok, programs} ->
        featured = Enum.take(programs, @featured_count)
        {:ok, featured}

      error ->
        error
    end
  end

  # Private helper to get the configured repository module
  defp repository_module do
    Application.get_env(:prime_youth, :program_catalog)[:repository]
  end
end
