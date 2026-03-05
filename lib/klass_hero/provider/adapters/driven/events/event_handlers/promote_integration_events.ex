defmodule KlassHero.Provider.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents do
  @moduledoc """
  Promotes Provider domain events to integration events for cross-context communication.

  Registered on the Provider DomainEventBus.
  """

  alias KlassHero.Provider.Domain.Events.ProviderIntegrationEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.IntegrationEventPublishing

  require Logger

  @spec handle(DomainEvent.t()) :: :ok | {:error, term()}
  def handle(%DomainEvent{event_type: :subscription_tier_changed} = event) do
    # Trigger: subscription_tier_changed domain event dispatched from ChangeSubscriptionTier use case
    # Why: other contexts (e.g., Entitlements) need to react to tier changes
    # Outcome: publish integration event on topic integration:provider:subscription_tier_changed
    result =
      event.aggregate_id
      |> ProviderIntegrationEvents.subscription_tier_changed(event.payload)
      |> IntegrationEventPublishing.publish()

    case result do
      :ok ->
        :ok

      {:error, reason} = error ->
        Logger.warning(
          "[PromoteIntegrationEvents] Failed to publish subscription_tier_changed",
          provider_id: event.aggregate_id,
          reason: inspect(reason)
        )

        error
    end
  end
end
