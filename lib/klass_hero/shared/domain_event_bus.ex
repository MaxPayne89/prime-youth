defmodule KlassHero.Shared.DomainEventBus do
  @moduledoc """
  Per-context handler registry for dispatching internal domain events.

  The GenServer acts as a registry only — it stores handler registrations and
  serves them on request. Actual handler execution happens in the caller's
  process via `dispatch/2`, preserving process context (process dictionary,
  test doubles, etc.).

  Each bounded context can have its own DomainEventBus for events that are
  internal to the context and should not cross context boundaries. Unlike
  integration events (which use PubSub), domain events are dispatched
  synchronously to registered handlers within the same process that calls
  `dispatch/2`.

  ## Usage

  Add to your application's supervision tree:

      {KlassHero.Shared.DomainEventBus, context: KlassHero.Identity}

  With init-time handler registration:

      {KlassHero.Shared.DomainEventBus,
       context: KlassHero.Identity,
       handlers: [
         {:child_updated, {MyHandler, :handle_child_updated}},
         {:user_deleted, {MyHandler, :handle_user_deleted}, priority: 10}
       ]}

  ## Subscribing

      DomainEventBus.subscribe(KlassHero.Identity, :child_updated, fn event ->
        # handle event
        :ok
      end)

      # With priority (lower number runs first, default 100)
      DomainEventBus.subscribe(KlassHero.Identity, :child_updated, handler_fn, priority: 10)

  ## Dispatching

      DomainEventBus.dispatch(KlassHero.Identity, %DomainEvent{event_type: :child_updated, ...})
  """

  use GenServer

  alias KlassHero.Shared.Domain.Events.DomainEvent

  require Logger

  @default_priority 100

  defstruct context: nil, handlers: %{}

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the DomainEventBus for a given context.

  ## Options

  - `:context` - (required) The bounded context module (e.g., `KlassHero.Identity`)
  - `:handlers` - (optional) List of init-time handler specs:
    - `{event_type, {Module, :function}}` — registers with default priority
    - `{event_type, {Module, :function}, opts}` — registers with given opts (e.g. `priority: 10`)
  """
  def start_link(opts) do
    context = Keyword.fetch!(opts, :context)
    handlers_spec = Keyword.get(opts, :handlers, [])
    name = process_name(context)

    GenServer.start_link(__MODULE__, %{context: context, handlers_spec: handlers_spec},
      name: name
    )
  end

  @doc """
  Subscribes a handler function to a specific event type on the given context's bus.

  The handler function receives a `%DomainEvent{}` and should return `:ok`.

  ## Options

  - `:priority` - Integer priority (lower runs first, default #{@default_priority})
  - `:mode` - Reserved for future async support (default `:sync`)
  """
  @spec subscribe(module(), atom(), (DomainEvent.t() -> :ok | {:error, term()}), keyword()) ::
          :ok
  def subscribe(context, event_type, handler_fn, opts \\ [])
      when is_atom(event_type) and is_function(handler_fn, 1) do
    GenServer.call(process_name(context), {:subscribe, event_type, handler_fn, opts})
  end

  @doc """
  Dispatches a domain event to all registered handlers for its event type.

  Handlers are fetched from the registry and executed in the caller's process,
  sorted by priority (lower number first). Returns `:ok` when all handlers
  succeed, or `{:error, failures}` if any handler returns an error or crashes.
  """
  @spec dispatch(module(), DomainEvent.t()) :: :ok | {:error, [term()]}
  def dispatch(context, %DomainEvent{event_type: event_type} = event) do
    handlers = GenServer.call(process_name(context), {:get_handlers, event_type})

    # Trigger: handler list may be empty for unsubscribed event types
    # Why: avoid unnecessary work and return :ok immediately
    # Outcome: empty handler list short-circuits to :ok
    execute_handlers(handlers, event)
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
  def init(%{context: context, handlers_spec: handlers_spec}) do
    Logger.info("DomainEventBus started for #{inspect(context)}")

    # Trigger: init-time handler specs may include {Module, :function} tuples
    # Why: allows static handler wiring at supervision tree startup
    # Outcome: handlers are resolved to captured functions and stored in the registry
    handlers = register_init_handlers(handlers_spec)

    {:ok, %__MODULE__{context: context, handlers: handlers}}
  end

  @impl true
  def handle_call({:subscribe, event_type, handler_fn, opts}, _from, state) do
    entry = {handler_fn, opts}

    # Trigger: appending to existing handler list for this event type
    # Why: preserves registration order for same-priority handlers
    # Outcome: new handler added at the end of the list for its event type
    handlers = Map.update(state.handlers, event_type, [entry], &(&1 ++ [entry]))
    {:reply, :ok, %{state | handlers: handlers}}
  end

  @impl true
  def handle_call({:get_handlers, event_type}, _from, state) do
    entries = Map.get(state.handlers, event_type, [])
    {:reply, entries, state}
  end

  # ============================================================================
  # Private — caller-side execution
  # ============================================================================

  defp execute_handlers([], _event), do: :ok

  defp execute_handlers(entries, event) do
    # Trigger: entries may have mixed priorities
    # Why: sort by priority so lower numbers execute first; stable sort preserves
    #      registration order for entries with the same priority
    # Outcome: handlers execute in deterministic priority order
    sorted =
      entries
      |> Enum.with_index()
      |> Enum.sort_by(fn {{_fn, opts}, index} ->
        {Keyword.get(opts, :priority, @default_priority), index}
      end)
      |> Enum.map(fn {{handler_fn, _opts}, _index} -> handler_fn end)

    failures =
      sorted
      |> Enum.map(&safe_call(&1, event))
      |> Enum.filter(&match?({:error, _}, &1))

    if failures == [], do: :ok, else: {:error, failures}
  end

  defp safe_call(handler_fn, event) do
    case handler_fn.(event) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
      unexpected -> {:error, {:unexpected_return, unexpected}}
    end
  rescue
    error ->
      Logger.error("[DomainEventBus] handler crashed for #{event.event_type}",
        error: Exception.message(error),
        stacktrace: Exception.format_stacktrace(__STACKTRACE__)
      )

      {:error, {:handler_crashed, error}}
  end

  # ============================================================================
  # Private — init-time handler resolution
  # ============================================================================

  defp register_init_handlers(specs) do
    Enum.reduce(specs, %{}, fn spec, acc ->
      {event_type, handler_fn, opts} = normalize_handler_spec(spec)
      entry = {handler_fn, opts}
      Map.update(acc, event_type, [entry], &(&1 ++ [entry]))
    end)
  end

  defp normalize_handler_spec({event_type, {module, function}}) do
    {event_type, Function.capture(module, function, 1), []}
  end

  defp normalize_handler_spec({event_type, {module, function}, opts}) do
    {event_type, Function.capture(module, function, 1), opts}
  end
end
