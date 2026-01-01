defmodule KlassHero.Shared.Adapters.Driven.Events.EventSubscriber do
  @moduledoc """
  GenServer that subscribes to PubSub topics and dispatches events to handlers.

  ## Usage

  Define a handler module implementing `ForHandlingEvents`:

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

  ## Options

  - `:handler` - (required) Module implementing ForHandlingEvents behaviour
  - `:topics` - (required) List of topic strings to subscribe to
  - `:pubsub` - (optional) PubSub server name, defaults to KlassHero.PubSub
  - `:name` - (optional) Process name, defaults to handler module name
  """

  use GenServer

  alias KlassHero.Shared.Domain.Events.DomainEvent

  require Logger

  defstruct [:handler, :topics, :pubsub]

  @type config :: [
          handler: module(),
          topics: [String.t()],
          pubsub: atom(),
          name: atom()
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

    state = %__MODULE__{
      handler: handler,
      topics: topics,
      pubsub: pubsub
    }

    subscribe_to_topics(state)

    Logger.info("EventSubscriber started for #{inspect(handler)} on topics: #{inspect(topics)}")

    {:ok, state}
  end

  @impl true
  def handle_info({:domain_event, %DomainEvent{} = event}, state) do
    handle_event_safely(event, state)
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp subscribe_to_topics(%{pubsub: pubsub, topics: topics}) do
    Enum.each(topics, fn topic ->
      :ok = Phoenix.PubSub.subscribe(pubsub, topic)
    end)
  end

  defp handle_event_safely(event, %{handler: handler}) do
    case handler.handle_event(event) do
      :ok ->
        Logger.debug("Event #{event.event_type} handled by #{inspect(handler)}")

      :ignore ->
        Logger.debug("Event #{event.event_type} ignored by #{inspect(handler)}")

      {:error, reason} ->
        Logger.error(
          "Handler #{inspect(handler)} failed to handle event #{event.event_type}: #{inspect(reason)}"
        )
    end
  rescue
    error ->
      Logger.error(
        "Handler #{inspect(handler)} crashed handling event #{event.event_type}: #{Exception.message(error)}"
      )
  end
end
