defmodule KlassHero.Provider.Domain.Ports.ForStoringProviderProfiles do
  @moduledoc """
  Write-only port for storing provider profiles in the Provider bounded context.

  Read operations have been moved to `ForQueryingProviderProfiles`.

  ## Expected Return Values

  - `create_provider_profile/1` - Returns `{:ok, ProviderProfile.t()}` or domain errors
  - `update/1` - Returns `{:ok, ProviderProfile.t()}` or errors

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  alias KlassHero.Provider.Domain.Models.ProviderProfile

  @doc """
  Creates a new provider profile in the repository.

  Accepts a map with provider profile attributes including identity_id and business_name (required).

  Returns:
  - `{:ok, ProviderProfile.t()}` - Provider profile created successfully
  - `{:error, :duplicate_resource}` - Provider profile already exists for this identity_id
  - `{:error, changeset}` - Validation failure
  """
  @callback create_provider_profile(attrs :: map()) ::
              {:ok, ProviderProfile.t()} | {:error, :duplicate_resource | term()}

  @doc """
  Updates an existing provider profile in the repository.

  Returns:
  - `{:ok, ProviderProfile.t()}` - Provider profile updated successfully
  - `{:error, :not_found}` - Provider profile does not exist
  - `{:error, changeset}` - Validation failure
  """
  @callback update(provider_profile :: ProviderProfile.t()) ::
              {:ok, ProviderProfile.t()} | {:error, :not_found | term()}
end
