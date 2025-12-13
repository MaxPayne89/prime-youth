defmodule PrimeYouth.Parenting.Domain.Ports.ForStoringParents do
  @moduledoc """
  Repository port for storing and retrieving parent profiles in the Parenting bounded context.

  This is a behaviour (interface) that defines the contract for parent persistence.
  It is implemented by adapters in the infrastructure layer (e.g., Ecto repositories).

  This port follows the Ports & Adapters architecture pattern, keeping the domain
  layer independent of infrastructure concerns.
  """

  alias PrimeYouth.Parenting.Domain.Models.Parent

  @typedoc """
  Specific error types for parent storage operations.

  - `:database_connection_error` - Network/connection issues (potentially retryable)
  - `:database_query_error` - SQL syntax, constraints, schema issues (non-retryable)
  - `:database_unavailable` - Generic/unexpected errors (fallback)
  - `:duplicate_identity` - Parent profile already exists for this identity_id
  - `:invalid_identity` - Identity ID does not exist in Accounts context
  """
  @type storage_error ::
          :database_connection_error
          | :database_query_error
          | :database_unavailable
          | :duplicate_identity
          | :invalid_identity

  @doc """
  Creates a new parent profile in the repository.

  Accepts a map with parent attributes including identity_id (required).
  Auto-generates UUID for id field if not provided.

  Returns:
  - `{:ok, Parent.t()}` - Parent profile created successfully
  - `{:error, :duplicate_identity}` - Parent profile already exists for this identity_id
  - `{:error, :invalid_identity}` - Identity ID does not exist
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      {:ok, parent} = create_parent_profile(%{identity_id: "550e8400-..."})
      {:error, :duplicate_identity} = create_parent_profile(%{identity_id: "existing-id"})
  """
  @callback create_parent_profile(map()) :: {:ok, Parent.t()} | {:error, storage_error()}

  @doc """
  Retrieves a parent profile by identity ID.

  Returns the parent profile associated with the given identity_id if found.

  Returns:
  - `{:ok, Parent.t()}` - Parent found with matching identity_id
  - `{:error, :not_found}` - No parent profile exists for this identity_id
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      {:ok, parent} = get_by_identity_id("550e8400-e29b-41d4-a716-446655440001")
      {:error, :not_found} = get_by_identity_id("non-existent-id")
  """
  @callback get_by_identity_id(String.t()) ::
              {:ok, Parent.t()} | {:error, :not_found | storage_error()}

  @doc """
  Checks if a parent profile exists for the given identity ID.

  Returns boolean indicating whether a parent profile exists.

  Returns:
  - `{:ok, true}` - Parent profile exists for this identity_id
  - `{:ok, false}` - No parent profile exists for this identity_id
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      {:ok, true} = has_profile?("550e8400-e29b-41d4-a716-446655440001")
      {:ok, false} = has_profile?("non-existent-id")
  """
  @callback has_profile?(String.t()) :: {:ok, boolean()} | {:error, storage_error()}
end
