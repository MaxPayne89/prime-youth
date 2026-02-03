defmodule KlassHero.Shared.Adapters.Driven.Events.EventSubscriber do
  @moduledoc """
  GenServer that subscribes to PubSub topics and dispatches events to handlers.

  Works for both domain events and integration events — the `:message_tag` option
  controls which PubSub message shape is expected, and `:event_label` controls how
  log messages describe the event kind.

  ## Usage

  Define a handler module implementing `ForHandlingEvents` (or `ForHandlingIntegrationEvents`):

      defmodule MyApp.MyEventHandler do
        @behaviour KlassHero.Shared.Domain.Ports.ForHandlingEvents

        @impl true
        def subscribed_events, do: [:user_registered, :user_confirmed]

        @impl true
        def handle_event(%{event_type: :user_registered} = event) do
          # Handle user registration
          :ok
        end

        def handle_event(_event), do: :ignore
      end

  Then start the subscriber in your supervision tree:

      children = [
        {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
         handler: MyApp.MyEventHandler,
         topics: ["user:user_registered", "user:user_confirmed"]}
      ]

  For integration events, pass the additional options:

      {EventSubscriber,
       handler: MyApp.IntegrationHandler,
       topics: ["integration:identity:child_data_anonymized"],
       message_tag: :integration_event,
       event_label: "Integration event"}

  ## Options

  - `:handler` - (required) Module implementing a handler behaviour
  - `:topics` - (required) List of topic strings to subscribe to
  - `:pubsub` - (optional) PubSub server name, defaults to KlassHero.PubSub
  - `:name` - (optional) Process name, defaults to handler module name
  - `:message_tag` - (optional) Atom tag in PubSub messages, defaults to `:domain_event`
  - `:event_label` - (optional) Human-readable label for log messages, defaults to `"Event"`
  """

  use GenServer

  require Logger

  defstruct [:handler, :topics, :pubsub, :message_tag, :event_label]

  @type config :: [
          handler: module(),
          topics: [String.t()],
          pubsub: atom(),
          name: atom(),
          message_tag: atom(),
          event_label: String.t()
        ]

  @spec start_link(config()) :: GenServer.on_start()
  def start_link(opts) do
    handler = Keyword.fetch!(opts, :handler)
    name = Keyword.get(opts, :name, handler)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    handler = Keyword.fetch!(opts, :handler)
    topics = Keyword.fetch!(opts, :topics)
    pubsub = Keyword.get(opts, :pubsub, KlassHero.PubSub)
    message_tag = Keyword.get(opts, :message_tag, :domain_event)
    event_label = Keyword.get(opts, :event_label, "Event")

    state = %__MODULE__{
      handler: handler,
      topics: topics,
      pubsub: pubsub,
      message_tag: message_tag,
      event_label: event_label
    }

    subscribe_to_topics(state)

    Logger.info("EventSubscriber started for #{inspect(handler)} on topics: #{inspect(topics)}")

    {:ok, state}
  end

  # Trigger: incoming PubSub message matches the configured message_tag
  # Why: single GenServer handles both domain and integration events via config
  # Outcome: event is dispatched to the handler module
  @impl true
  def handle_info({tag, event}, %{message_tag: tag} = state) do
    handle_event_safely(event, state)
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    Logger.warning("[EventSubscriber] Received unknown message for #{inspect(state.handler)}")
    {:noreply, state}
  end

  defp subscribe_to_topics(%{pubsub: pubsub, topics: topics}) do
    Enum.each(topics, fn topic ->
      :ok = Phoenix.PubSub.subscribe(pubsub, topic)
    end)
  end

  defp handle_event_safely(event, %{handler: handler, event_label: label}) do
    case handler.handle_event(event) do
      :ok ->
        Logger.debug("#{label} #{event.event_type} handled by #{inspect(handler)}")

      :ignore ->
        Logger.debug("#{label} #{event.event_type} ignored by #{inspect(handler)}")

      {:error, reason} ->
        Logger.error(
          "Handler #{inspect(handler)} failed to handle #{String.downcase(label)} #{event.event_type}: #{inspect(reason)}"
        )

      unexpected ->
        Logger.warning(
          "Handler #{inspect(handler)} returned unexpected value for #{String.downcase(label)} #{event.event_type}: #{inspect(unexpected)}"
        )
    end
  rescue
    error ->
      Logger.error(
        "Handler #{inspect(handler)} crashed handling #{String.downcase(label)} #{event.event_type}: #{Exception.message(error)}",
        stacktrace: Exception.format_stacktrace(__STACKTRACE__)
      )
  end
end
