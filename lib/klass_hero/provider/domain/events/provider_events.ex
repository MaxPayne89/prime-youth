defmodule KlassHero.Provider.Domain.Events.ProviderEvents do
  @moduledoc """
  Factory module for creating Provider domain events.

  ## Event Types

  - `subscription_tier_changed` - A provider's subscription tier was changed
  - `stripe_identity_verified` - Stripe Identity verification completed successfully (18+ confirmed)
  - `stripe_identity_failed` - Stripe Identity verification failed or was canceled

  All events are returned as `DomainEvent` structs.
  """

  alias KlassHero.Provider.Domain.Models.ProviderProfile
  alias KlassHero.Shared.Domain.Events.DomainEvent

  @aggregate_type :provider

  @doc "Creates a subscription_tier_changed event."
  @spec subscription_tier_changed(ProviderProfile.t(), atom(), keyword()) :: DomainEvent.t()
  def subscription_tier_changed(%ProviderProfile{} = profile, previous_tier, opts \\ [])
      when is_atom(previous_tier) do
    payload = %{
      provider_id: profile.id,
      previous_tier: previous_tier,
      new_tier: profile.subscription_tier
    }

    DomainEvent.new(:subscription_tier_changed, profile.id, @aggregate_type, payload, opts)
  end

  @doc "Creates a stripe_identity_verified event. Fired when Stripe confirms identity and 18+ age gate passes."
  @spec stripe_identity_verified(ProviderProfile.t()) :: DomainEvent.t()
  def stripe_identity_verified(%ProviderProfile{} = profile) do
    payload = %{
      provider_id: profile.id,
      stripe_identity_session_id: profile.stripe_identity_session_id
    }

    DomainEvent.new(:stripe_identity_verified, profile.id, @aggregate_type, payload)
  end

  @doc "Creates a stripe_identity_failed event. Fired when Stripe verification fails, is canceled, or 18+ age gate fails."
  @spec stripe_identity_failed(ProviderProfile.t(), atom()) :: DomainEvent.t()
  def stripe_identity_failed(%ProviderProfile{} = profile, status)
      when status in [:requires_input, :canceled] do
    payload = %{
      provider_id: profile.id,
      stripe_identity_session_id: profile.stripe_identity_session_id,
      failure_status: status
    }

    DomainEvent.new(:stripe_identity_failed, profile.id, @aggregate_type, payload)
  end
end
