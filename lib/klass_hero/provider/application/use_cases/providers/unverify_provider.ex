defmodule KlassHero.Provider.Application.UseCases.Providers.UnverifyProvider do
  @moduledoc """
  Use case for admin revoking provider verification.

  Orchestrates the provider unverification workflow:
  1. Retrieves the provider profile from the repository
  2. Sets verified: false and clears verified_at timestamp
  3. Persists the updated profile
  4. Publishes an integration event for cross-context notification

  This use case is idempotent - unverifying an already unverified provider succeeds.
  """

  alias KlassHero.Provider.Domain.Models.ProviderProfile
  alias KlassHero.Shared.Domain.Events.IntegrationEvent
  alias KlassHero.Shared.IntegrationEventPublishing

  @repository Application.compile_env!(:klass_hero, [:provider, :for_storing_provider_profiles])

  @doc """
  Revokes verification from a provider profile.

  ## Parameters

  - `provider_id` - ID of the provider profile to unverify
  - `admin_id` - ID of the admin performing the unverification (for audit)

  ## Returns

  - `{:ok, ProviderProfile.t()}` on success with verified=false
  - `{:error, :not_found}` if provider profile doesn't exist
  """
  def execute(%{provider_id: provider_id, admin_id: admin_id}) do
    with {:ok, profile} <- @repository.get(provider_id),
         {:ok, unverified} <- ProviderProfile.unverify(profile),
         {:ok, persisted} <- @repository.update(unverified),
         :ok <- publish_event(persisted, admin_id) do
      {:ok, persisted}
    end
  end

  # Trigger: Provider unverification completed
  # Why: Other contexts (e.g., Program Catalog) may need to know about unverified providers
  # Outcome: Integration event published to PubSub for cross-context consumption
  defp publish_event(profile, admin_id) do
    event =
      IntegrationEvent.new(
        :provider_unverified,
        :provider,
        :provider,
        profile.id,
        %{
          provider_id: profile.id,
          business_name: profile.business_name,
          admin_id: admin_id
        }
      )

    IntegrationEventPublishing.publish(event)
  end
end
