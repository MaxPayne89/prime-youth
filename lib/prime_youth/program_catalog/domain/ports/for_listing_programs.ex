defmodule PrimeYouth.ProgramCatalog.Domain.Ports.ForListingPrograms do
  @moduledoc """
  Repository port for listing programs in the Program Catalog bounded context.

  This is a behaviour (interface) that defines the contract for program persistence.
  It is implemented by adapters in the infrastructure layer (e.g., Ecto repositories).

  This port follows the Ports & Adapters architecture pattern, keeping the domain
  layer independent of infrastructure concerns.
  """

  alias PrimeYouth.ProgramCatalog.Domain.Models.Program

  @doc """
  Lists all valid programs from the repository.

  Only programs with all required fields populated are returned.
  Programs are returned in ascending order by title.

  Returns:
  - `{:ok, [Program.t()]}` - List of valid programs (may be empty)
  - `{:error, :database_error}` - Database connection or query failure

  ## Examples

      {:ok, programs} = list_all_programs()
      {:error, :database_error} = list_all_programs()
  """
  @callback list_all_programs() :: {:ok, [Program.t()]} | {:error, :database_error}
end
