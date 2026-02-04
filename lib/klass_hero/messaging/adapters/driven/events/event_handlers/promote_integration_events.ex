defmodule KlassHero.Messaging.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents do
  @moduledoc """
  Promotes Messaging domain events to integration events for cross-context communication.

  Registered on the Messaging DomainEventBus. When a relevant domain event is
  dispatched, this handler creates the corresponding integration event and
  publishes it via PubSub.

  ## Error strategy

  Swallows publish failures — the GDPR anonymization transaction has already
  committed, so the data change is durable. The integration event is best-effort
  notification to downstream contexts.
  """

  alias KlassHero.Messaging.Domain.Events.MessagingIntegrationEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.IntegrationEventPublishing

  require Logger

  @doc """
  Handles a domain event by promoting it to the corresponding integration event.
  """
  @spec handle(DomainEvent.t()) :: :ok
  def handle(%DomainEvent{event_type: :user_data_anonymized} = event) do
    user_id = event.payload.user_id

    integration_event = MessagingIntegrationEvents.message_data_anonymized(user_id)

    case IntegrationEventPublishing.publish(integration_event) do
      :ok ->
        :ok

      {:error, reason} ->
        # Trigger: PubSub publish failed after transaction committed
        # Why: data change is durable, integration event is best-effort notification
        # Outcome: log warning, return :ok so bus reports success to use case
        Logger.warning("Failed to publish message_data_anonymized integration event",
          user_id: user_id,
          reason: inspect(reason)
        )

        :ok
    end
  end
end
