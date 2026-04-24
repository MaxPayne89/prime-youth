defmodule KlassHero.Provider.Adapters.Driven.Projections.ProviderPrograms do
  @moduledoc """
  Event-driven projection maintaining the `provider_programs` read table.

  Subscribes to Program Catalog integration events and mirrors program
  ownership + display metadata locally so Provider use cases never reach
  across the context boundary at runtime.

  ## Architecture

  This is a "driven adapter" in the Ports & Adapters architecture — it's driven
  by integration events from the Program Catalog context. The read-side
  repository (`ProviderProgramRepository`) queries the table this projection
  writes.

  ## Startup Behavior

  On init, the GenServer:
  1. Subscribes to `integration:program_catalog:program_created` and
     `integration:program_catalog:program_updated` PubSub topics
  2. Uses `handle_continue(:bootstrap)` to bulk-upsert from the Program Catalog
     `programs` write table

  Pass `skip_bootstrap: true` in tests to skip both PubSub subscription and
  bootstrap, allowing direct `send/2` of events for isolated testing.

  ## Event Handling

  - `:program_created` — upsert row keyed by `program_id`
  - `:program_updated` — upsert row keyed by `program_id` (replaces mutable fields)

  Programs in the Program Catalog have no first-class status field today, so
  the projection records every program as `"active"`. This column exists to
  support future filtering (e.g. archived/draft) without requiring a migration.
  """

  use GenServer

  import Ecto.Query

  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProgramProjectionSchema
  alias KlassHero.Repo
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  require Logger

  @program_created_topic "integration:program_catalog:program_created"
  @program_updated_topic "integration:program_catalog:program_updated"

  @default_status "active"

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  @doc """
  Starts the ProviderPrograms projection GenServer.

  ## Options

  - `:name` - Process name (defaults to `__MODULE__`)
  - `:skip_bootstrap` - When `true`, skips PubSub subscription and bootstrap
    (for isolated testing). Defaults to `false`.
  """
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Rebuilds the projection from the Program Catalog write table.

  Useful after seeding write tables directly (bypassing integration events).
  Blocks until the rebuild is complete.
  """
  @spec rebuild(GenServer.name()) :: :ok
  def rebuild(name \\ __MODULE__) do
    GenServer.call(name, :rebuild, :infinity)
  end

  # ---------------------------------------------------------------------------
  # Server Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    skip_bootstrap = Keyword.get(opts, :skip_bootstrap, false)

    if skip_bootstrap do
      {:ok, %{bootstrapped: false}}
    else
      Phoenix.PubSub.subscribe(KlassHero.PubSub, @program_created_topic)
      Phoenix.PubSub.subscribe(KlassHero.PubSub, @program_updated_topic)
      {:ok, %{bootstrapped: false}, {:continue, :bootstrap}}
    end
  end

  @impl true
  def handle_continue(:bootstrap, state) do
    attempt_bootstrap(state)
  end

  @impl true
  def handle_call(:rebuild, _from, state) do
    count = bootstrap_from_write_table()
    Logger.info("ProviderPrograms rebuilt", count: count)
    {:reply, :ok, %{state | bootstrapped: true}}
  end

  # Trigger: scheduled retry after a transient bootstrap failure
  # Why: re-enter handle_continue logic without crashing the GenServer outright
  # Outcome: re-attempts bootstrap with the accumulated retry_count in state
  @impl true
  def handle_info(:retry_bootstrap, state) do
    {:noreply, state, {:continue, :bootstrap}}
  end

  # Trigger: Received a program_created integration event
  # Why: a new program was created, the projection must add a row for it
  # Outcome: row inserted (or replaced if duplicate event arrives)
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :program_created} = event}, state) do
    Logger.debug("ProviderPrograms projecting program_created",
      program_id: event.entity_id,
      event_id: event.event_id
    )

    upsert_from_event(event)
    {:noreply, state}
  end

  # Trigger: Received a program_updated integration event
  # Why: program fields changed, the projection's display metadata must reflect them
  # Outcome: existing row updated (or inserted if missing due to race with bootstrap)
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :program_updated} = event}, state) do
    Logger.debug("ProviderPrograms projecting program_updated",
      program_id: event.entity_id,
      event_id: event.event_id
    )

    upsert_from_event(event)
    {:noreply, state}
  end

  # Catch-all for unhandled messages — logged so misrouted events are traceable
  @impl true
  def handle_info(msg, state) do
    Logger.warning("ProviderPrograms received unexpected message",
      message: inspect(msg, limit: 200)
    )

    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private Functions
  # ---------------------------------------------------------------------------

  # Trigger: bootstrap attempt with retry logic
  # Why: transient DB failures shouldn't crash the GenServer immediately
  # Outcome: successful bootstrap or scheduled retry (up to 3 times before crashing)
  defp attempt_bootstrap(state) do
    count = bootstrap_from_write_table()
    Logger.info("ProviderPrograms projection started", count: count)
    {:noreply, %{state | bootstrapped: true}}
  rescue
    error ->
      retry_count = Map.get(state, :retry_count, 0) + 1

      if retry_count > 3 do
        # Trigger: exhausted retries
        # Why: persistent failure indicates real infrastructure issue
        # Outcome: crash to let supervisor handle with its own restart strategy
        reraise error, __STACKTRACE__
      else
        Logger.error("ProviderPrograms: bootstrap failed, scheduling retry",
          error: Exception.message(error),
          retry_count: retry_count
        )

        Process.send_after(self(), :retry_bootstrap, 5_000 * retry_count)
        {:noreply, Map.put(state, :retry_count, retry_count)}
      end
  end

  # Trigger: program_created or program_updated event received
  # Why: upsert keeps both events idempotent and tolerant to bootstrap races
  # Outcome: row written keyed on program_id
  defp upsert_from_event(%IntegrationEvent{} = event) do
    payload = event.payload
    program_id = event.entity_id
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs = %{
      program_id: program_id,
      provider_id: Map.fetch!(payload, :provider_id),
      name: extract_name(payload),
      status: extract_status(payload),
      inserted_at: now,
      updated_at: now
    }

    Repo.insert_all(
      ProviderProgramProjectionSchema,
      [attrs],
      on_conflict: {:replace, [:provider_id, :name, :status, :updated_at]},
      conflict_target: [:program_id]
    )
  end

  # Trigger: bootstrap phase — read table may be empty or stale
  # Why: cold start recovery — populate read table from Program Catalog write table
  # Outcome: provider_programs contains one row per program with current name + provider
  defp bootstrap_from_write_table do
    programs =
      ProgramSchema
      |> select([p], %{program_id: p.id, provider_id: p.provider_id, name: p.title})
      |> Repo.all()

    if programs == [] do
      0
    else
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      rows =
        Enum.map(programs, fn program ->
          Map.merge(program, %{
            status: @default_status,
            inserted_at: now,
            updated_at: now
          })
        end)

      {count, _} =
        Repo.insert_all(
          ProviderProgramProjectionSchema,
          rows,
          on_conflict: {:replace, [:provider_id, :name, :status, :updated_at]},
          conflict_target: [:program_id]
        )

      count
    end
  end

  # Trigger: payload may carry program name as :title (Program Catalog convention) or :name
  # Why: tolerate both naming styles for forward-compatibility
  # Outcome: returns the program's display name; raises with a clear message if absent
  defp extract_name(%{title: title}) when is_binary(title), do: title
  defp extract_name(%{name: name}) when is_binary(name), do: name

  defp extract_name(payload) do
    # Trigger: malformed event payload missing both :title and :name
    # Why: silent nil would crash later as a NOT NULL violation with no diagnostic context
    # Outcome: log the payload shape, then crash explicitly so the supervisor can recover
    Logger.error("ProviderPrograms received event without :title or :name (payload_keys=#{inspect(Map.keys(payload))})")

    raise ArgumentError, "Program payload missing :title or :name field"
  end

  # Trigger: payload may not include a status (Program Catalog has no status today)
  # Why: provider_programs.status is NOT NULL — fall back to a sensible default
  # Outcome: returns the payload status as a string, or "active" if absent
  defp extract_status(%{status: status}) when is_binary(status), do: status

  defp extract_status(%{status: status}) when is_atom(status) and status not in [nil, true, false],
    do: Atom.to_string(status)

  defp extract_status(_), do: @default_status
end
