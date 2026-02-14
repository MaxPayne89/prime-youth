defmodule KlassHero.ProgramCatalog.Domain.Ports.ForUpdatingPrograms do
  @moduledoc """
  Repository port for updating programs in the Program Catalog bounded context.

  This is a behaviour (interface) that defines the contract for program write operations.
  It is implemented by adapters in the infrastructure layer (e.g., Ecto repositories).

  This port follows the Ports & Adapters architecture pattern, keeping the domain
  layer independent of infrastructure concerns.

  ## Expected Return Values

  - `update/1` - Returns `{:ok, Program.t()}` or domain errors:
    - `{:error, :stale_data}` - Optimistic lock conflict
    - `{:error, :not_found}` - Program doesn't exist
    - `{:error, changeset}` - Validation failure

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  alias KlassHero.ProgramCatalog.Domain.Models.Program

  @doc """
  Updates an existing program with optimistic locking.

  Uses the program's ID to locate the record and applies the changes. The update
  will fail if the program was modified by another process since it was loaded
  (optimistic lock conflict).

  The lock_version field is automatically incremented on successful update.

  Returns:
  - `{:ok, Program.t()}` - Successfully updated program
  - `{:error, :stale_data}` - Program was modified by another process
  - `{:error, :not_found}` - Program ID does not exist
  - `{:error, changeset}` - Validation failure
  """
  @callback update(program :: Program.t()) ::
              {:ok, Program.t()} | {:error, :stale_data | :not_found | Ecto.Changeset.t()}
end
