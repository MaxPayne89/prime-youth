defmodule PrimeYouth.ProgramCatalog.Domain.Ports.ForListingPrograms do
  @moduledoc """
  Repository port for listing programs in the Program Catalog bounded context.

  This is a behaviour (interface) that defines the contract for program persistence.
  It is implemented by adapters in the infrastructure layer (e.g., Ecto repositories).

  This port follows the Ports & Adapters architecture pattern, keeping the domain
  layer independent of infrastructure concerns.
  """

  alias PrimeYouth.ProgramCatalog.Domain.Models.Program

  @typedoc """
  Specific error types for program listing operations.

  - `:database_connection_error` - Network/connection issues (potentially retryable)
  - `:database_query_error` - SQL syntax, constraints, schema issues (non-retryable)
  - `:database_unavailable` - Generic/unexpected errors (fallback)
  """
  @type list_error ::
          :database_connection_error
          | :database_query_error
          | :database_unavailable

  @doc """
  Lists all valid programs from the repository.

  Only programs with all required fields populated are returned.
  Programs are returned in ascending order by title.

  Returns:
  - `{:ok, [Program.t()]}` - List of valid programs (may be empty)
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      {:ok, programs} = list_all_programs()
      {:error, :database_connection_error} = list_all_programs()
      {:error, :database_query_error} = list_all_programs()
  """
  @callback list_all_programs() :: {:ok, [Program.t()]} | {:error, list_error()}
end
