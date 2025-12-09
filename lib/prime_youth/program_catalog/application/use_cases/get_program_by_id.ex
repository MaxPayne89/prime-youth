defmodule PrimeYouth.ProgramCatalog.Application.UseCases.GetProgramById do
  @moduledoc """
  Use case for retrieving a single program by its unique ID from the Program Catalog.

  This use case orchestrates the retrieval of a specific program from the repository.
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

      {:ok, program} = GetProgramById.execute("550e8400-e29b-41d4-a716-446655440001")
      {:error, :not_found} = GetProgramById.execute("550e8400-e29b-41d4-a716-446655440099")
      {:error, :database_connection_error} = GetProgramById.execute("invalid-uuid")
  """

  alias PrimeYouth.ProgramCatalog.Domain.Models.Program
  alias PrimeYouth.ProgramCatalog.Domain.Ports.ForListingPrograms

  @doc """
  Executes the use case to retrieve a specific program by ID (UUID).

  Retrieves a single program from the repository that has complete data
  (all required fields populated) and matches the given ID.

  Returns:
  - `{:ok, Program.t()}` - Program found with matching ID
  - `{:error, :not_found}` - No program exists with the given ID
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      # Successful retrieval
      {:ok, program} = GetProgramById.execute("550e8400-e29b-41d4-a716-446655440001")
      IO.puts(program.title)

      # Program not found
      {:error, :not_found} = GetProgramById.execute("550e8400-e29b-41d4-a716-446655440099")

      # Database errors
      {:error, :database_connection_error} = GetProgramById.execute("invalid-uuid")
      {:error, :database_query_error} = GetProgramById.execute("malformed-uuid")
  """
  @spec execute(String.t()) ::
          {:ok, Program.t()} | {:error, :not_found | ForListingPrograms.list_error()}
  def execute(id) when is_binary(id) do
    repository_module().get_by_id(id)
  end

  # Private helper to get the configured repository module
  defp repository_module do
    Application.get_env(:prime_youth, :program_catalog)[:repository]
  end
end
