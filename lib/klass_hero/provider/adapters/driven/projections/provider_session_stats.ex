defmodule KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionStats do
  @moduledoc """
  Event-driven projection maintaining the `provider_session_stats` read table.

  This GenServer subscribes to `session_completed` integration events from the
  Participation context and maintains a denormalized counter of completed sessions
  per provider+program pair.

  ## Architecture

  This is a "driven adapter" in the Ports & Adapters architecture — it's driven
  by integration events from the Participation context. The read-side repository
  (`SessionStatsRepository`) queries the table this projection writes.

  ## Startup Behavior

  On init, the GenServer:
  1. Subscribes to the `integration:participation:session_completed` PubSub topic
  2. Uses `handle_continue(:bootstrap)` to bulk-upsert initial counts from the ACL

  Pass `skip_bootstrap: true` in tests to skip both PubSub subscription and
  bootstrap, allowing direct `send/2` of events for isolated testing.

  ## Event Handling

  - `:session_completed` — atomic SQL increment of `sessions_completed_count`
    via `INSERT ... ON CONFLICT DO UPDATE SET count = count + 1`

  ## Dashboard Notification

  After each upsert, broadcasts `:session_stats_updated` to the provider's
  stats PubSub topic so the dashboard LiveView can refresh.
  """

  use GenServer

  import Ecto.Query

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.SessionStatsSchema
  alias KlassHero.Repo
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  require Logger

  @session_completed_topic "integration:participation:session_completed"

  @acl Application.compile_env!(:klass_hero, [:provider, :for_resolving_session_stats])

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  @doc """
  Starts the ProviderSessionStats projection GenServer.

  ## Options

  - `:name` - Process name (defaults to `__MODULE__`)
  - `:skip_bootstrap` - When `true`, skips PubSub subscription and bootstrap
    (for isolated testing). Defaults to `false`.
  """
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
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
      Phoenix.PubSub.subscribe(KlassHero.PubSub, @session_completed_topic)
      {:ok, %{bootstrapped: false}, {:continue, :bootstrap}}
    end
  end

  @impl true
  def handle_continue(:bootstrap, state) do
    attempt_bootstrap(state)
  end

  @impl true
  def handle_info(:retry_bootstrap, state) do
    {:noreply, state, {:continue, :bootstrap}}
  end

  # Trigger: Received a session_completed integration event
  # Why: a session was completed, the counter for that provider+program must increment
  # Outcome: atomic SQL increment of sessions_completed_count, dashboard notified
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :session_completed} = event}, state) do
    %{provider_id: provider_id, program_id: program_id, program_title: program_title} =
      event.payload

    Logger.debug("ProviderSessionStats projecting session_completed",
      provider_id: provider_id,
      program_id: program_id,
      event_id: event.event_id
    )

    upsert_session_count(provider_id, program_id, program_title)
    notify_dashboard(provider_id)

    {:noreply, state}
  end

  # Catch-all for unhandled messages
  @impl true
  def handle_info(msg, state) do
    Logger.warning("ProviderSessionStats received unexpected message",
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
    count = bootstrap_counts()
    Logger.info("ProviderSessionStats projection started", count: count)
    {:noreply, %{state | bootstrapped: true}}
  rescue
    error ->
      retry_count = Map.get(state, :retry_count, 0) + 1

      if retry_count > 3 do
        reraise error, __STACKTRACE__
      else
        Logger.error("ProviderSessionStats: bootstrap failed, scheduling retry",
          error: Exception.message(error),
          retry_count: retry_count
        )

        Process.send_after(self(), :retry_bootstrap, 5_000 * retry_count)
        {:noreply, Map.put(state, :retry_count, retry_count)}
      end
  end

  # Trigger: bootstrap phase -- read table may be empty or stale
  # Why: cold start recovery -- populate read table from ACL cross-context query
  # Outcome: provider_session_stats contains one row per provider+program with correct counts
  defp bootstrap_counts do
    case @acl.list_completed_session_counts() do
      {:ok, []} ->
        0

      {:ok, rows} ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        entries =
          Enum.map(rows, fn row ->
            %{
              id: Ecto.UUID.generate(),
              provider_id: row.provider_id,
              program_id: row.program_id,
              program_title: row.program_title,
              sessions_completed_count: row.sessions_completed_count,
              inserted_at: now,
              updated_at: now
            }
          end)

        {count, _} =
          Repo.insert_all(SessionStatsSchema, entries,
            on_conflict: {:replace_all_except, [:id, :inserted_at]},
            conflict_target: [:provider_id, :program_id]
          )

        count

      {:error, reason} ->
        raise "Bootstrap ACL query failed: #{inspect(reason)}"
    end
  end

  # Trigger: session_completed event received
  # Why: atomic increment avoids race conditions with concurrent events
  # Outcome: row inserted with count=1 or existing count incremented by 1
  defp upsert_session_count(provider_id, program_id, program_title) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %SessionStatsSchema{}
    |> Ecto.Changeset.change(%{
      id: Ecto.UUID.generate(),
      provider_id: provider_id,
      program_id: program_id,
      program_title: program_title,
      sessions_completed_count: 1,
      inserted_at: now,
      updated_at: now
    })
    |> Repo.insert!(
      on_conflict:
        from(s in SessionStatsSchema,
          update: [
            set: [
              sessions_completed_count: fragment("? + 1", s.sessions_completed_count),
              program_title: ^program_title,
              updated_at: ^now
            ]
          ]
        ),
      conflict_target: [:provider_id, :program_id]
    )
  end

  # Trigger: upsert completed successfully
  # Why: dashboard LiveView needs to know stats changed to refresh the counter
  # Outcome: PubSub broadcast to provider-specific topic
  defp notify_dashboard(provider_id) do
    Phoenix.PubSub.broadcast(
      KlassHero.PubSub,
      "provider:#{provider_id}:stats_updated",
      :session_stats_updated
    )
  end
end
