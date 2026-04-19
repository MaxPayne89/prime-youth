defmodule KlassHero.Provider.Domain.Ports.ForQueryingProviderProfiles do
  @moduledoc """
  Read-only port for querying provider profiles in the Provider bounded context.

  Separated from `ForStoringProviderProfiles` (write-only) to support CQRS at
  the port level. Read operations never mutate state.
  """

  alias KlassHero.Provider.Domain.Models.ProviderProfile

  @doc """
  Retrieves a provider profile by identity ID.

  Returns:
  - `{:ok, ProviderProfile.t()}` - Provider profile found with matching identity_id
  - `{:error, :not_found}` - No provider profile exists for this identity_id
  """
  @callback get_by_identity_id(identity_id :: binary()) ::
              {:ok, ProviderProfile.t()} | {:error, :not_found}

  @doc """
  Checks if a provider profile exists for the given identity ID.

  Returns boolean directly (no error tuple for simple existence check).
  """
  @callback has_profile?(identity_id :: binary()) :: boolean()

  @doc """
  Retrieves a provider profile by its ID.

  Returns:
  - `{:ok, ProviderProfile.t()}` - Provider profile found with matching ID
  - `{:error, :not_found}` - No provider profile exists with this ID
  """
  @callback get(id :: binary()) :: {:ok, ProviderProfile.t()} | {:error, :not_found}

  @doc """
  Lists all verified provider profile IDs.

  Used by projections and caching layers to track verification status.

  Returns:
  - `{:ok, [String.t()]}` - List of verified provider profile IDs (may be empty)
  """
  @callback list_verified_ids() :: {:ok, [String.t()]}
end
