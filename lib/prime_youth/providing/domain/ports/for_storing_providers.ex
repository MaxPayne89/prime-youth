defmodule PrimeYouth.Providing.Domain.Ports.ForStoringProviders do
  @moduledoc """
  Repository port for storing and retrieving provider profiles in the Providing bounded context.

  This is a behaviour (interface) that defines the contract for provider persistence.
  It is implemented by adapters in the infrastructure layer (e.g., Ecto repositories).

  ## Expected Return Values

  - `create_provider_profile/1` - Returns `{:ok, Provider.t()}` or domain errors
  - `get_by_identity_id/1` - Returns `{:ok, Provider.t()}` or `{:error, :not_found}`
  - `has_profile?/1` - Returns boolean directly

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  @doc """
  Creates a new provider profile in the repository.

  Accepts a map with provider attributes including identity_id and business_name (required).

  Returns:
  - `{:ok, Provider.t()}` - Provider profile created successfully
  - `{:error, :duplicate_identity}` - Provider profile already exists for this identity_id
  - `{:error, changeset}` - Validation failure
  """
  @callback create_provider_profile(attrs :: map()) ::
              {:ok, term()} | {:error, :duplicate_identity | term()}

  @doc """
  Retrieves a provider profile by identity ID.

  Returns:
  - `{:ok, Provider.t()}` - Provider found with matching identity_id
  - `{:error, :not_found}` - No provider profile exists for this identity_id
  """
  @callback get_by_identity_id(identity_id :: binary()) ::
              {:ok, term()} | {:error, :not_found}

  @doc """
  Checks if a provider profile exists for the given identity ID.

  Returns boolean directly (no error tuple for simple existence check).
  """
  @callback has_profile?(identity_id :: binary()) :: boolean()
end
