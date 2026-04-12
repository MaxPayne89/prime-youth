defmodule KlassHero.Provider.Application.Queries.ProviderProfileQueries do
  @moduledoc """
  Query module for provider profile reads.

  Centralises all read operations that depend on the provider profile repository,
  keeping the facade free of direct repository references.
  """

  alias KlassHero.Provider.Domain.Models.ProviderProfile

  @provider_repository Application.compile_env!(:klass_hero, [
                         :provider,
                         :for_querying_provider_profiles
                       ])

  @doc """
  Retrieves a provider profile by identity ID.
  """
  @spec get_by_identity(String.t()) :: {:ok, ProviderProfile.t()} | {:error, :not_found}
  def get_by_identity(identity_id) when is_binary(identity_id) do
    @provider_repository.get_by_identity_id(identity_id)
  end

  @doc """
  Checks if a provider profile exists for the given identity ID.
  """
  @spec has_profile?(String.t()) :: boolean()
  def has_profile?(identity_id) when is_binary(identity_id) do
    @provider_repository.has_profile?(identity_id)
  end

  @doc """
  Returns the provider profile by ID.
  """
  @spec get_profile(String.t()) :: {:ok, ProviderProfile.t()} | {:error, :not_found}
  def get_profile(provider_id) when is_binary(provider_id) do
    @provider_repository.get(provider_id)
  end

  @doc """
  Gets the user (identity) ID for a provider profile ID.

  Used by cross-context consumers (e.g. Messaging) to resolve
  `conversation.provider_id` (provider profile ID) back to a user ID
  for permission and authorization checks.
  """
  @spec get_identity_id_for_provider(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_identity_id_for_provider(provider_id) when is_binary(provider_id) do
    case @provider_repository.get(provider_id) do
      {:ok, %ProviderProfile{identity_id: identity_id}} -> {:ok, identity_id}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  List all verified provider IDs (for projections).
  """
  @spec list_verified_ids() :: {:ok, [String.t()]}
  def list_verified_ids do
    @provider_repository.list_verified_ids()
  end
end
