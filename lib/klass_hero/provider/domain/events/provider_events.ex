defmodule KlassHero.Provider.Domain.Events.ProviderEvents do
  @moduledoc """
  Factory module for creating Provider domain events.

  ## Event Types

  - `subscription_tier_changed` - A provider's subscription tier was changed

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
end
