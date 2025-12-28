defmodule PrimeYouth.Parenting.Domain.Ports.ForStoringParents do
  @moduledoc """
  Repository port for storing and retrieving parent profiles in the Parenting bounded context.

  This is a behaviour (interface) that defines the contract for parent persistence.
  It is implemented by adapters in the infrastructure layer (e.g., Ecto repositories).

  ## Expected Return Values

  - `create_parent_profile/1` - Returns `{:ok, Parent.t()}` or domain errors
  - `get_by_identity_id/1` - Returns `{:ok, Parent.t()}` or `{:error, :not_found}`
  - `has_profile?/1` - Returns boolean directly

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  @doc """
  Creates a new parent profile in the repository.

  Accepts a map with parent attributes including identity_id (required).

  Returns:
  - `{:ok, Parent.t()}` - Parent profile created successfully
  - `{:error, :duplicate_identity}` - Parent profile already exists for this identity_id
  - `{:error, changeset}` - Validation failure
  """
  @callback create_parent_profile(attrs :: map()) ::
              {:ok, term()} | {:error, :duplicate_identity | term()}

  @doc """
  Retrieves a parent profile by identity ID.

  Returns:
  - `{:ok, Parent.t()}` - Parent found with matching identity_id
  - `{:error, :not_found}` - No parent profile exists for this identity_id
  """
  @callback get_by_identity_id(identity_id :: binary()) ::
              {:ok, term()} | {:error, :not_found}

  @doc """
  Checks if a parent profile exists for the given identity ID.

  Returns boolean directly (no error tuple for simple existence check).
  """
  @callback has_profile?(identity_id :: binary()) :: boolean()
end
