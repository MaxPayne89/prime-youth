defmodule KlassHero.Shared.DomainEventBus do
  @moduledoc """
  Per-context GenServer for dispatching internal domain events.

  Each bounded context can have its own DomainEventBus for events that are
  internal to the context and should not cross context boundaries. Unlike
  integration events (which use PubSub), domain events are dispatched
  synchronously to registered handlers within the same process.

  ## Usage

  Add to your application's supervision tree:

      {KlassHero.Shared.DomainEventBus, context: KlassHero.Identity}

  The process name is derived from the context: `KlassHero.Identity.DomainEventBus`

  ## Subscribing

      DomainEventBus.subscribe(KlassHero.Identity, :child_updated, fn event ->
        # handle event
        :ok
      end)

  ## Dispatching

      DomainEventBus.dispatch(KlassHero.Identity, %DomainEvent{event_type: :child_updated, ...})
  """

  use GenServer

  alias KlassHero.Shared.Domain.Events.DomainEvent

  require Logger

  defstruct context: nil, handlers: %{}

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the DomainEventBus for a given context.

  ## Options

  - `:context` - (required) The bounded context module (e.g., `KlassHero.Identity`)
  """
  def start_link(opts) do
    context = Keyword.fetch!(opts, :context)
    name = process_name(context)
    GenServer.start_link(__MODULE__, %{context: context}, name: name)
  end

  @doc """
  Subscribes a handler function to a specific event type on the given context's bus.

  The handler function receives a `%DomainEvent{}` and should return `:ok`.
  """
  @spec subscribe(module(), atom(), (DomainEvent.t() -> :ok | {:error, term()})) :: :ok
  def subscribe(context, event_type, handler_fn)
      when is_atom(event_type) and is_function(handler_fn, 1) do
    GenServer.call(process_name(context), {:subscribe, event_type, handler_fn})
  end

  @doc """
  Dispatches a domain event to all registered handlers for its event type.

  Handlers are called sequentially. Returns `:ok` when all handlers succeed,
  or `{:error, failures}` if any handler returns an error or crashes.
  """
  @spec dispatch(module(), DomainEvent.t()) :: :ok | {:error, [term()]}
  def dispatch(context, %DomainEvent{} = event) do
    GenServer.call(process_name(context), {:dispatch, event})
  end

  @doc """
  Derives the process name for a context's DomainEventBus.
  """
  @spec process_name(module()) :: atom()
  def process_name(context) do
    Module.concat(context, DomainEventBus)
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init(%{context: context}) do
    Logger.info("DomainEventBus started for #{inspect(context)}")
    {:ok, %__MODULE__{context: context, handlers: %{}}}
  end

  @impl true
  def handle_call({:subscribe, event_type, handler_fn}, _from, state) do
    handlers = Map.update(state.handlers, event_type, [handler_fn], &[handler_fn | &1])
    {:reply, :ok, %{state | handlers: handlers}}
  end

  @impl true
  def handle_call({:dispatch, %DomainEvent{event_type: event_type} = event}, _from, state) do
    handlers = Map.get(state.handlers, event_type, [])

    failures =
      handlers
      |> Enum.map(fn handler_fn ->
        try do
          case handler_fn.(event) do
            :ok -> :ok
            {:error, reason} -> {:error, reason}
            unexpected -> {:error, {:unexpected_return, unexpected}}
          end
        rescue
          error ->
            Logger.error("[DomainEventBus] handler crashed for #{event_type}",
              error: Exception.message(error),
              stacktrace: Exception.format_stacktrace(__STACKTRACE__)
            )

            {:error, {:handler_crashed, error}}
        end
      end)
      |> Enum.filter(&match?({:error, _}, &1))

    reply = if failures == [], do: :ok, else: {:error, failures}
    {:reply, reply, state}
  end
end
