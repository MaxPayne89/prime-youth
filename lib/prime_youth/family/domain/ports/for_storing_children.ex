defmodule PrimeYouth.Family.Domain.Ports.ForStoringChildren do
  @moduledoc """
  Port for child persistence operations.

  Defines the contract for storing and retrieving children without exposing
  infrastructure details. Implementations will be provided by repository adapters.

  ## Expected Return Values

  - `get_by_id/1` - Returns `{:ok, Child.t()}` or `{:error, :not_found}`
  - `create/1` - Returns `{:ok, Child.t()}` or `{:error, changeset}`
  - `list_by_parent/1` - Returns list of children directly

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  @doc """
  Retrieves a child by their unique identifier.

  Returns:
  - `{:ok, Child.t()}` - Child found successfully
  - `{:error, :not_found}` - Child ID doesn't exist
  """
  @callback get_by_id(binary()) :: {:ok, term()} | {:error, :not_found}

  @doc """
  Creates a new child record.

  Returns:
  - `{:ok, Child.t()}` - Child created successfully
  - `{:error, changeset}` - Validation failed
  """
  @callback create(map()) :: {:ok, term()} | {:error, term()}

  @doc """
  Lists all children for a given parent.

  Returns list of children (may be empty).
  """
  @callback list_by_parent(binary()) :: [term()]
end
