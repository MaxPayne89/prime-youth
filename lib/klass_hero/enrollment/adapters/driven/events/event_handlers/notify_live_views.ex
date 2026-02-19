defmodule KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.NotifyLiveViews do
  @moduledoc """
  Routes Enrollment domain events to PubSub topics for LiveView real-time updates.

  Uses derive_topic pattern: topic = "\#{aggregate_type}:\#{event_type}"

  ## Error strategy

  Swallows publish failures — the use case has already committed.
  PubSub delivery is best-effort notification to connected LiveViews.
  """

  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.EventPublishing

  require Logger

  @doc "Handles a domain event by publishing it to the derived PubSub topic."
  @spec handle(DomainEvent.t()) :: :ok
  def handle(%DomainEvent{} = event) do
    topic = derive_topic(event)
    safe_publish(event, topic)
  end

  @doc "Derives a PubSub topic from a domain event's aggregate_type and event_type."
  @spec derive_topic(DomainEvent.t()) :: String.t()
  def derive_topic(%DomainEvent{aggregate_type: agg, event_type: evt}) do
    build_topic(agg, evt)
  end

  @doc "Builds a PubSub topic string from aggregate type and event type atoms."
  @spec build_topic(atom(), atom()) :: String.t()
  def build_topic(aggregate_type, event_type) do
    "#{aggregate_type}:#{event_type}"
  end

  defp safe_publish(event, topic) do
    case EventPublishing.publisher_module().publish(event, topic) do
      :ok ->
        :ok

      {:error, reason} ->
        # Trigger: PubSub publish failed after use case committed
        # Why: transaction is durable, LiveView notification is best-effort
        # Outcome: log warning, return :ok so bus reports success
        Logger.warning("Failed to publish #{event.event_type} to #{topic}",
          event_type: event.event_type,
          topic: topic,
          reason: inspect(reason)
        )

        :ok
    end
  end
end
