defmodule PrimeYouth.Providing.Domain.Ports.ForStoringProviders do
  @moduledoc """
  Repository port for storing and retrieving provider profiles in the Providing bounded context.

  This is a behaviour (interface) that defines the contract for provider persistence.
  It is implemented by adapters in the infrastructure layer (e.g., Ecto repositories).

  This port follows the Ports & Adapters architecture pattern, keeping the domain
  layer independent of infrastructure concerns.
  """

  alias PrimeYouth.Providing.Domain.Models.Provider

  @typedoc """
  Specific error types for provider storage operations.

  - `:database_connection_error` - Network/connection issues (potentially retryable)
  - `:database_query_error` - SQL syntax, constraints, schema issues (non-retryable)
  - `:database_unavailable` - Generic/unexpected errors (fallback)
  - `:duplicate_identity` - Provider profile already exists for this identity_id
  - `:invalid_identity` - Identity ID does not exist in Accounts context
  - `{:validation_error, [String.t()]}` - Domain validation errors (list of error messages)
  """
  @type storage_error ::
          :database_connection_error
          | :database_query_error
          | :database_unavailable
          | :duplicate_identity
          | :invalid_identity
          | {:validation_error, [String.t()]}

  @doc """
  Creates a new provider profile in the repository.

  Accepts a map with provider attributes including identity_id and business_name (required).
  Auto-generates UUID for id field if not provided.

  Returns:
  - `{:ok, Provider.t()}` - Provider profile created successfully
  - `{:error, :duplicate_identity}` - Provider profile already exists for this identity_id
  - `{:error, :invalid_identity}` - Identity ID does not exist
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      {:ok, provider} = create_provider_profile(%{identity_id: "550e8400-...", business_name: "My Business"})
      {:error, :duplicate_identity} = create_provider_profile(%{identity_id: "existing-id", business_name: "Another"})
  """
  @callback create_provider_profile(map()) :: {:ok, Provider.t()} | {:error, storage_error()}

  @doc """
  Retrieves a provider profile by identity ID.

  Returns the provider profile associated with the given identity_id if found.

  Returns:
  - `{:ok, Provider.t()}` - Provider found with matching identity_id
  - `{:error, :not_found}` - No provider profile exists for this identity_id
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      {:ok, provider} = get_by_identity_id("550e8400-e29b-41d4-a716-446655440001")
      {:error, :not_found} = get_by_identity_id("non-existent-id")
  """
  @callback get_by_identity_id(String.t()) ::
              {:ok, Provider.t()} | {:error, :not_found | storage_error()}

  @doc """
  Checks if a provider profile exists for the given identity ID.

  Returns boolean indicating whether a provider profile exists.

  Returns:
  - `{:ok, true}` - Provider profile exists for this identity_id
  - `{:ok, false}` - No provider profile exists for this identity_id
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      {:ok, true} = has_profile?("550e8400-e29b-41d4-a716-446655440001")
      {:ok, false} = has_profile?("non-existent-id")
  """
  @callback has_profile?(String.t()) :: {:ok, boolean()} | {:error, storage_error()}
end
