defmodule PrimeYouth.ProgramCatalog.Domain.Ports.ForUpdatingPrograms do
  @moduledoc """
  Repository port for updating programs in the Program Catalog bounded context.

  This is a behaviour (interface) that defines the contract for program write operations.
  It is implemented by adapters in the infrastructure layer (e.g., Ecto repositories).

  This port follows the Ports & Adapters architecture pattern, keeping the domain
  layer independent of infrastructure concerns. It is separate from ForListingPrograms
  to maintain single responsibility principle (SRP).
  """

  alias PrimeYouth.ProgramCatalog.Domain.Models.Program

  @typedoc """
  Specific error types for program update operations.

  - `:stale_data` - Optimistic lock conflict (record modified by another process)
  - `:not_found` - Program ID does not exist
  - `:constraint_violation` - Database constraint violation (invalid data)
  - `:database_connection_error` - Network/connection issues (potentially retryable)
  - `:database_query_error` - SQL syntax, constraints, schema issues (non-retryable)
  - `:database_unavailable` - Generic/unexpected errors (fallback)
  """
  @type update_error ::
          :stale_data
          | :not_found
          | :constraint_violation
          | :database_connection_error
          | :database_query_error
          | :database_unavailable

  @doc """
  Updates an existing program with optimistic locking.

  Uses the program's ID to locate the record and applies the changes. The update
  will fail if the program was modified by another process since it was loaded
  (optimistic lock conflict).

  The lock_version field is automatically incremented on successful update.
  Callers should refetch the program after a stale_data error to get the latest
  version before retrying.

  Parameters:
  - `program` - Domain Program entity with updated fields

  Returns:
  - `{:ok, Program.t()}` - Successfully updated program with incremented lock_version
  - `{:error, :stale_data}` - Program was modified by another process (optimistic lock)
  - `{:error, :not_found}` - Program ID does not exist in the database
  - `{:error, :constraint_violation}` - Data validation failed at database level
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or schema mismatch
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      # Successful update
      program = %Program{id: "uuid", title: "Updated Title", ...}
      {:ok, updated_program} = update(program)
      updated_program.title  # "Updated Title"

      # Optimistic lock conflict
      {:error, :stale_data} = update(stale_program)

      # Program not found
      {:error, :not_found} = update(%Program{id: "non-existent-uuid", ...})

      # Constraint violation
      {:error, :constraint_violation} = update(%Program{price: -100, ...})

  ## Concurrency Handling

  When multiple processes attempt to update the same program concurrently:

  1. First process succeeds, lock_version increments
  2. Subsequent processes fail with :stale_data
  3. Failed processes should refetch and retry if appropriate
  """
  @callback update(Program.t()) :: {:ok, Program.t()} | {:error, update_error()}
end
