defmodule KlassHero.Identity.Application.UseCases.Providers.UnverifyProvider do
  @moduledoc """
  Use case for admin revoking provider verification.

  Orchestrates the provider unverification workflow:
  1. Retrieves the provider profile from the repository
  2. Sets verified: false and clears verified_at timestamp
  3. Persists the updated profile
  4. Publishes an integration event for cross-context notification

  This use case is idempotent - unverifying an already unverified provider succeeds.
  """

  alias KlassHero.Shared.Domain.Events.IntegrationEvent
  alias KlassHero.Shared.IntegrationEventPublishing

  @doc """
  Revokes verification from a provider profile.

  ## Parameters

  - `provider_id` - ID of the provider profile to unverify
  - `admin_id` - ID of the admin performing the unverification (for audit)

  ## Returns

  - `{:ok, ProviderProfile.t()}` on success with verified=false
  - `{:error, :not_found}` if provider profile doesn't exist
  """
  def execute(%{provider_id: provider_id, admin_id: _admin_id}) do
    with {:ok, profile} <- get_profile(provider_id),
         {:ok, unverified} <- unverify_profile(profile),
         {:ok, persisted} <- save_profile(unverified),
         :ok <- publish_event(persisted) do
      {:ok, persisted}
    end
  end

  defp get_profile(provider_id), do: repository().get(provider_id)

  # Trigger: Provider verification needs to be revoked
  # Why: Clears the verified flag and removes the verification timestamp
  # Outcome: Domain model updated with verified=false and verified_at=nil
  defp unverify_profile(profile) do
    unverified = %{
      profile
      | verified: false,
        verified_at: nil,
        updated_at: DateTime.utc_now()
    }

    {:ok, unverified}
  end

  defp save_profile(profile), do: repository().update(profile)

  # Trigger: Provider unverification completed
  # Why: Other contexts (e.g., Program Catalog) may need to know about unverified providers
  # Outcome: Integration event published to PubSub for cross-context consumption
  defp publish_event(profile) do
    event =
      IntegrationEvent.new(
        :provider_unverified,
        :identity,
        :provider,
        profile.id,
        %{
          provider_id: profile.id,
          business_name: profile.business_name
        }
      )

    IntegrationEventPublishing.publish(event)
  end

  defp repository do
    Application.get_env(:klass_hero, :identity)[:for_storing_provider_profiles] ||
      KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ProviderProfileRepository
  end
end
