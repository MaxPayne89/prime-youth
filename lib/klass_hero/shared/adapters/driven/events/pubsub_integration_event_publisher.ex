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
  alias KlassHero.Shared.Adapters.Driven.Events.PubSubBroadcaster
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
    PubSubBroadcaster.broadcast(event, topic,
      config_key: :integration_event_publisher,
      message_tag: :integration_event,
      log_label: "integration event",
      extra_metadata: [entity_id: event.entity_id]
    )
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

        enqueue_critical_job(args, event, handler_ref)
      end)
    end
  end

  defp enqueue_critical_job(args, event, handler_ref) do
    case CriticalEventWorker.insert_job(args) do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        # Trigger: Oban job insertion failed for a critical integration event
        # Why: PubSub broadcast already succeeded, but the durable fallback is now absent
        # Outcome: error-level log for operator alerting — event relies solely on PubSub path
        Logger.error(
          "Failed to enqueue durable delivery job for critical integration event " <>
            "#{event.event_type} (#{event.event_id}), handler #{handler_ref}. " <>
            "Durable delivery guarantee voided for this handler.",
          event_id: event.event_id,
          event_type: event.event_type,
          handler: handler_ref,
          reason: inspect(reason)
        )
    end
  end
end
