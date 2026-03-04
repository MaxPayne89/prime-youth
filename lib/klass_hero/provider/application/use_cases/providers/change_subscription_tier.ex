defmodule KlassHero.Provider.Application.UseCases.Providers.ChangeSubscriptionTier do
  @moduledoc """
  Use case for changing a provider's subscription tier.

  Orchestrates domain validation and persistence through the repository port.
  """

  alias KlassHero.Provider.Domain.Models.ProviderProfile

  @repository Application.compile_env!(:klass_hero, [:provider, :for_storing_provider_profiles])

  @doc """
  Changes the subscription tier for a provider profile.

  Delegates tier validation to the domain model (`ProviderProfile.change_tier/2`),
  then persists the result via the repository port.

  Returns:
  - `{:ok, ProviderProfile.t()}` on success
  - `{:error, :same_tier}` if new tier matches current
  - `{:error, :invalid_tier}` if tier is not valid
  - `{:error, :not_found}` if provider doesn't exist in DB
  """
  def execute(%ProviderProfile{} = profile, new_tier) when is_atom(new_tier) do
    with {:ok, updated_profile} <- ProviderProfile.change_tier(profile, new_tier) do
      @repository.update(updated_profile)
    end
  end
end
