defmodule KlassHero.Identity.Application.UseCases.Providers.VerifyProvider do
  @moduledoc """
  Use case for admin verifying a provider.

  Orchestrates the provider verification workflow:
  1. Retrieves the provider profile from the repository
  2. Sets verified: true and verified_at timestamp
  3. Persists the updated profile
  4. Publishes an integration event for cross-context notification

  This use case is idempotent - verifying an already verified provider succeeds
  and updates the verified_at timestamp.
  """

  alias KlassHero.Shared.Domain.Events.IntegrationEvent
  alias KlassHero.Shared.IntegrationEventPublishing

  @doc """
  Verifies a provider profile.

  ## Parameters

  - `provider_id` - ID of the provider profile to verify
  - `admin_id` - ID of the admin performing the verification (for audit)

  ## Returns

  - `{:ok, ProviderProfile.t()}` on success with verified=true
  - `{:error, :not_found}` if provider profile doesn't exist
  """
  def execute(%{provider_id: provider_id, admin_id: _admin_id}) do
    with {:ok, profile} <- get_profile(provider_id),
         {:ok, verified} <- verify_profile(profile),
         {:ok, persisted} <- save_profile(verified),
         :ok <- publish_event(persisted) do
      {:ok, persisted}
    end
  end

  defp get_profile(provider_id), do: repository().get(provider_id)

  # Trigger: Provider needs to be marked as verified
  # Why: Sets the verified flag and records the verification timestamp
  # Outcome: Domain model updated with verified=true and current timestamp
  defp verify_profile(profile) do
    verified = %{
      profile
      | verified: true,
        verified_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
    }

    {:ok, verified}
  end

  defp save_profile(profile), do: repository().update(profile)

  # Trigger: Provider verification completed
  # Why: Other contexts (e.g., Program Catalog) may need to know about verified providers
  # Outcome: Integration event published to PubSub for cross-context consumption
  defp publish_event(profile) do
    event =
      IntegrationEvent.new(
        :provider_verified,
        :identity,
        :provider,
        profile.id,
        %{
          provider_id: profile.id,
          business_name: profile.business_name,
          verified_at: profile.verified_at
        }
      )

    IntegrationEventPublishing.publish(event)
  end

  defp repository do
    Application.get_env(:klass_hero, :identity)[:for_storing_provider_profiles] ||
      KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ProviderProfileRepository
  end
end
