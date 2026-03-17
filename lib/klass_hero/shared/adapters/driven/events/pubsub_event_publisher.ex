defmodule KlassHero.Shared.Adapters.Driven.Events.PubSubEventPublisher do
  @moduledoc """
  Phoenix.PubSub implementation of the ForPublishingEvents port.

  This adapter publishes domain events to Phoenix.PubSub topics following
  the topic naming convention: `{aggregate_type}:{event_type}`

  ## Configuration

  The PubSub server name is configured in config:

      config :klass_hero, :event_publisher,
        module: KlassHero.Shared.Adapters.Driven.Events.PubSubEventPublisher,
        pubsub: KlassHero.PubSub

  ## Message Format

  Events are broadcast as tuples: `{:domain_event, %DomainEvent{}}`

  Subscribers receive events via `handle_info/2`:

      def handle_info({:domain_event, event}, state) do
        # Process event
        {:noreply, state}
      end
  """

  @behaviour KlassHero.Shared.Domain.Ports.ForPublishingEvents

  alias KlassHero.Shared.Adapters.Driven.Events.PubSubBroadcaster
  alias KlassHero.Shared.Domain.Events.DomainEvent

  @impl true
  def publish(%DomainEvent{} = event) do
    topic = derive_topic(event)
    publish(event, topic)
  end

  @impl true
  def publish(%DomainEvent{} = event, topic) when is_binary(topic) do
    PubSubBroadcaster.broadcast(event, topic,
      config_key: :event_publisher,
      message_tag: :domain_event,
      log_label: "event",
      extra_metadata: [aggregate_id: event.aggregate_id]
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
  Builds a topic string from aggregate type and event type.

  This is the canonical function for topic string construction.
  Use this for subscribing to specific event topics.

  Format: `{aggregate_type}:{event_type}`

  ## Examples

      iex> PubSubEventPublisher.build_topic(:user, :registered)
      "user:registered"

      iex> PubSubEventPublisher.build_topic(:enrollment, :confirmed)
      "enrollment:confirmed"
  """
  @spec build_topic(atom(), atom()) :: String.t()
  def build_topic(aggregate_type, event_type) do
    "#{aggregate_type}:#{event_type}"
  end

  @doc """
  Derives the topic name from a domain event.

  Extracts aggregate type and event type from the event and builds
  the topic string. Used internally when publishing events.

  ## Examples

      iex> alias KlassHero.Shared.Domain.Events.DomainEvent
      iex> alias KlassHero.Shared.Adapters.Driven.Events.PubSubEventPublisher
      iex> event = DomainEvent.new(:user_registered, 1, :user, %{})
      iex> PubSubEventPublisher.derive_topic(event)
      "user:user_registered"
  """
  @spec derive_topic(DomainEvent.t()) :: String.t()
  def derive_topic(%DomainEvent{aggregate_type: agg_type, event_type: event_type}) do
    build_topic(agg_type, event_type)
  end
end
