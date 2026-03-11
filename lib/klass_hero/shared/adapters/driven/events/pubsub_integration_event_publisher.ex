defmodule KlassHero.Shared.Adapters.Driven.Events.PubSubIntegrationEventPublisher do
  @moduledoc """
  Phoenix.PubSub implementation of the ForPublishingIntegrationEvents port.

  This adapter publishes integration events to Phoenix.PubSub topics following
  the topic naming convention: `integration:{source_context}:{event_type}`

  ## Configuration

  The PubSub server name is configured in config:

      config :klass_hero, :integration_event_publisher,
        module: KlassHero.Shared.Adapters.Driven.Events.PubSubIntegrationEventPublisher,
        pubsub: KlassHero.PubSub

  ## Message Format

  Events are broadcast as tuples: `{:integration_event, %IntegrationEvent{}}`

  Subscribers receive events via `handle_info/2`:

      def handle_info({:integration_event, event}, state) do
        # Process event
        {:noreply, state}
      end
  """

  @behaviour KlassHero.Shared.Domain.Ports.ForPublishingIntegrationEvents

  alias KlassHero.Shared.Adapters.Driven.Events.CriticalEventHandlerRegistry
  alias KlassHero.Shared.Adapters.Driven.Events.CriticalEventSerializer
  alias KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorker
  alias KlassHero.Shared.Domain.Events.IntegrationEvent
  alias KlassHero.Shared.Domain.Services.CriticalEventDispatcher

  require Logger

  @impl true
  def publish(%IntegrationEvent{} = event) do
    topic = derive_topic(event)

    case publish(event, topic) do
      :ok ->
        # Trigger: event may be marked critical
        # Why: critical integration events need durable delivery as Oban fallback
        # Outcome: one CriticalEventWorker job enqueued per registered handler
        maybe_enqueue_critical_jobs(event, topic)
        :ok

      error ->
        error
    end
  end

  @impl true
  def publish(%IntegrationEvent{} = event, topic) when is_binary(topic) do
    pubsub = pubsub_server()

    case Phoenix.PubSub.broadcast(pubsub, topic, {:integration_event, event}) do
      :ok ->
        log_event_published(event, topic)
        :ok

      {:error, reason} = error ->
        log_publish_error(event, topic, reason)
        error
    end
  end

  @impl true
  def publish_all(events) when is_list(events) do
    results = Enum.map(events, &publish/1)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end

  @doc """
  Builds a topic string from source context and event type.

  Format: `integration:{source_context}:{event_type}`

  ## Examples

      iex> PubSubIntegrationEventPublisher.build_topic(:identity, :child_data_anonymized)
      "integration:identity:child_data_anonymized"
  """
  @spec build_topic(atom(), atom()) :: String.t()
  def build_topic(source_context, event_type) do
    "integration:#{source_context}:#{event_type}"
  end

  @doc """
  Derives the topic name from an integration event.

  ## Examples

      iex> event = IntegrationEvent.new(:child_data_anonymized, :identity, :child, "uuid", %{})
      iex> PubSubIntegrationEventPublisher.derive_topic(event)
      "integration:identity:child_data_anonymized"
  """
  @spec derive_topic(IntegrationEvent.t()) :: String.t()
  def derive_topic(%IntegrationEvent{source_context: ctx, event_type: event_type}) do
    build_topic(ctx, event_type)
  end

  # Trigger: event has criticality: :critical and handlers are registered
  # Why: PubSub is fire-and-forget — Oban provides durable retry if PubSub path fails
  # Outcome: one Oban job per handler, each going through CriticalEventDispatcher
  defp maybe_enqueue_critical_jobs(%IntegrationEvent{} = event, topic) do
    if IntegrationEvent.critical?(event) do
      handlers = CriticalEventHandlerRegistry.handlers_for(topic)

      Enum.each(handlers, fn {_module, _function} = handler_tuple ->
        handler_ref = CriticalEventDispatcher.handler_ref(handler_tuple)

        args =
          CriticalEventSerializer.serialize(event)
          |> Map.put("handler", handler_ref)

        CriticalEventWorker.insert_job(args)
      end)
    end
  end

  defp pubsub_server do
    Application.get_env(:klass_hero, :integration_event_publisher, [])
    |> Keyword.get(:pubsub, KlassHero.PubSub)
  end

  defp log_event_published(event, topic) do
    Logger.debug(
      "Published integration event #{event.event_type} (#{event.event_id}) to topic #{topic}",
      event_id: event.event_id,
      event_type: event.event_type,
      entity_id: event.entity_id,
      topic: topic
    )
  end

  defp log_publish_error(event, topic, reason) do
    Logger.error(
      "Failed to publish integration event #{event.event_type} (#{event.event_id}) to topic #{topic}: #{inspect(reason)}",
      event_id: event.event_id,
      event_type: event.event_type,
      entity_id: event.entity_id,
      topic: topic,
      error: reason
    )
  end
end
