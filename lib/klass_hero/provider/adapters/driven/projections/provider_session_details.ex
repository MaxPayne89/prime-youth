defmodule KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionDetails do
  @moduledoc """
  Event-driven projection maintaining `provider_session_details`.

  Subscribes to Participation session/attendance events and Provider staff events.
  Self-heals on every boot by replaying the bootstrap query into the read table.
  """

  use GenServer

  import Ecto.Query

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema
  alias KlassHero.Repo
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  require Logger

  @session_created_topic "integration:participation:session_created"
  @session_started_topic "integration:participation:session_started"
  @session_completed_topic "integration:participation:session_completed"
  @session_cancelled_topic "integration:participation:session_cancelled"
  @roster_seeded_topic "integration:participation:roster_seeded"
  @child_checked_in_topic "integration:participation:child_checked_in"
  @child_checked_out_topic "integration:participation:child_checked_out"
  @child_marked_absent_topic "integration:participation:child_marked_absent"
  @staff_assigned_topic "integration:provider:staff_assigned_to_program"
  @staff_unassigned_topic "integration:provider:staff_unassigned_from_program"

  @topics [
    @session_created_topic,
    @session_started_topic,
    @session_completed_topic,
    @session_cancelled_topic,
    @roster_seeded_topic,
    @child_checked_in_topic,
    @child_checked_out_topic,
    @child_marked_absent_topic,
    @staff_assigned_topic,
    @staff_unassigned_topic
  ]

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Rebuilds the read table from write models. Useful after seeds."
  def rebuild(name \\ __MODULE__), do: GenServer.call(name, :rebuild, :infinity)

  @impl true
  def init(_opts) do
    Enum.each(@topics, &Phoenix.PubSub.subscribe(KlassHero.PubSub, &1))
    {:ok, %{}, {:continue, :bootstrap}}
  end

  @impl true
  def handle_continue(:bootstrap, state) do
    # Self-heal the read table from write tables on every boot. Transient DB
    # failures reschedule via :retry_bootstrap; persistent failures propagate
    # through repeated retries until the supervisor intervenes.
    case do_bootstrap() do
      {:ok, count} ->
        Logger.info("ProviderSessionDetails bootstrap complete", count: count)
        {:noreply, state}

      {:error, reason} ->
        Logger.warning("ProviderSessionDetails bootstrap failed; retrying",
          reason: inspect(reason)
        )

        Process.send_after(self(), :retry_bootstrap, 1_000)
        {:noreply, state}
    end
  end

  # Seeds bypass the event bus, so `rebuild/1` refreshes the read table from
  # write tables via the same bootstrap path used on init.
  @impl true
  def handle_call(:rebuild, _from, state) do
    {:ok, count} = do_bootstrap()
    Logger.info("ProviderSessionDetails rebuilt", count: count)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:retry_bootstrap, state) do
    {:noreply, state, {:continue, :bootstrap}}
  end

  # Trigger: Received a session_created integration event
  # Why: a new session exists — project a row with defaults, resolving
  #      program_title/provider_id from the programs write table and the
  #      currently assigned staff from program_staff_assignments
  # Outcome: one row upserted into provider_session_details
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :session_created} = event}, state) do
    Logger.debug("ProviderSessionDetails projecting session_created",
      session_id: event.entity_id,
      event_id: event.event_id
    )

    project_session_created(event.payload)
    {:noreply, state}
  end

  # Trigger: session entered the live window (instructor started it)
  # Why: dashboard badge flips from scheduled → in_progress
  # Outcome: row's status column updated to :in_progress
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :session_started} = event}, state) do
    update_status(event.entity_id, :in_progress)
    {:noreply, state}
  end

  # Trigger: session finished (end-of-session finalization)
  # Why: dashboard badge flips from in_progress → completed
  # Outcome: row's status column updated to :completed
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :session_completed} = event}, state) do
    update_status(event.entity_id, :completed)
    {:noreply, state}
  end

  # Trigger: session cancelled (by provider or system)
  # Why: dashboard badge reflects cancellation, independent of prior status
  # Outcome: row's status column updated to :cancelled
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :session_cancelled} = event}, state) do
    update_status(event.entity_id, :cancelled)
    {:noreply, state}
  end

  # Participation seeded the roster for a session — set total_count so the
  # dashboard can render "X / Y checked in" denominators.
  @impl true
  def handle_info(
        {:integration_event,
         %IntegrationEvent{event_type: :roster_seeded, payload: %{seeded_count: seeded_count}} = event},
        state
      ) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(d in ProviderSessionDetailSchema, where: d.session_id == ^event.entity_id)
    |> Repo.update_all(set: [total_count: seeded_count, updated_at: now])
    |> warn_if_missing("roster_seeded", session_id: event.entity_id, seeded_count: seeded_count)

    {:noreply, state}
  end

  # Bump the monotonic checked_in counter. Check-outs and absences are
  # intentionally not reflected (see below) — once counted on check-in, a child
  # stays counted for the "how many showed up" view.
  @impl true
  def handle_info(
        {:integration_event,
         %IntegrationEvent{event_type: :child_checked_in, payload: %{session_id: session_id}} = event},
        state
      ) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(d in ProviderSessionDetailSchema, where: d.session_id == ^session_id)
    |> Repo.update_all(inc: [checked_in_count: 1], set: [updated_at: now])
    |> warn_if_missing("child_checked_in", session_id: session_id, record_id: event.entity_id)

    {:noreply, state}
  end

  # Trigger: attendance taker undid a check-in (child_checked_out)
  # Why: once a child is counted on check-in, they stay counted for the day's
  #      "how many showed up" view; undo events are intentionally not reflected
  #      in checked_in_count. Logged at debug to confirm the no-op is deliberate.
  # Outcome: no state change.
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :child_checked_out} = event}, state) do
    Logger.debug("ProviderSessionDetails ignoring child_checked_out (counter is monotonic)",
      record_id: event.entity_id
    )

    {:noreply, state}
  end

  # Trigger: attendance taker marked a child absent
  # Why: absence is the complement of check-in and does not change the "how
  #      many showed up" count. Logged at debug to confirm the no-op is deliberate.
  # Outcome: no state change.
  @impl true
  def handle_info({:integration_event, %IntegrationEvent{event_type: :child_marked_absent} = event}, state) do
    Logger.debug("ProviderSessionDetails ignoring child_marked_absent (no effect on checked_in_count)",
      record_id: event.entity_id
    )

    {:noreply, state}
  end

  # Trigger: staff_assigned_to_program integration event (provider assigned a
  #          new staff member to one of their programs)
  # Why: upcoming sessions should reflect the new assignment on the dashboard.
  #      Historical (in_progress/completed/cancelled) rows retain their
  #      pre-existing attribution — bulk update is intentionally scoped to
  #      :scheduled rows only.
  # Outcome: all :scheduled rows for the program get current_assigned_staff_id
  #          and current_assigned_staff_name set to the new staff values.
  @impl true
  def handle_info(
        {:integration_event,
         %IntegrationEvent{
           event_type: :staff_assigned_to_program,
           payload: %{staff_member_id: staff_id, program_id: program_id}
         }},
        state
      ) do
    staff_name = lookup_staff_name(staff_id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(d in ProviderSessionDetailSchema,
      where: d.program_id == ^program_id and d.status == :scheduled
    )
    |> Repo.update_all(
      set: [
        current_assigned_staff_id: staff_id,
        current_assigned_staff_name: staff_name,
        updated_at: now
      ]
    )

    {:noreply, state}
  end

  # Trigger: staff_unassigned_from_program integration event (provider removed
  #          a staff member's assignment from one of their programs)
  # Why: upcoming sessions must drop the stale attribution. Historical rows
  #      intentionally retain their pre-existing staff_id/name as part of the
  #      session's audit trail — bulk clear is scoped to :scheduled rows only.
  # Outcome: all :scheduled rows for the program have current_assigned_staff_*
  #          columns cleared to nil.
  @impl true
  def handle_info(
        {:integration_event,
         %IntegrationEvent{event_type: :staff_unassigned_from_program, payload: %{program_id: program_id}}},
        state
      ) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(d in ProviderSessionDetailSchema,
      where: d.program_id == ^program_id and d.status == :scheduled
    )
    |> Repo.update_all(
      set: [
        current_assigned_staff_id: nil,
        current_assigned_staff_name: nil,
        updated_at: now
      ]
    )

    {:noreply, state}
  end

  # Final catch-all: the projection subscribes to multiple topics, and some
  # carry unrelated event types we explicitly do not care about. Silently drop
  # them — matching the no-op discipline used for child_checked_out and
  # child_marked_absent above.
  @impl true
  def handle_info({:integration_event, _event}, state), do: {:noreply, state}

  defp project_session_created(%{
         session_id: session_id,
         program_id: program_id,
         session_date: session_date,
         start_time: start_time,
         end_time: end_time
       }) do
    %{program_title: program_title, provider_id: provider_id, staff_id: staff_id, staff_name: staff_name} =
      resolve_program_context(program_id)

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs = %{
      session_id: session_id,
      program_id: program_id,
      program_title: program_title,
      provider_id: provider_id,
      session_date: session_date,
      start_time: start_time,
      end_time: end_time,
      status: :scheduled,
      current_assigned_staff_id: staff_id,
      current_assigned_staff_name: staff_name,
      checked_in_count: 0,
      total_count: 0,
      inserted_at: now,
      updated_at: now
    }

    Repo.insert_all(
      ProviderSessionDetailSchema,
      [attrs],
      on_conflict:
        {:replace_all_except,
         [
           :session_id,
           :inserted_at,
           :status,
           :checked_in_count,
           :total_count,
           :cover_staff_id,
           :cover_staff_name
         ]},
      conflict_target: [:session_id]
    )
  end

  # Trigger: handle_continue(:bootstrap) or handle_call(:rebuild)
  # Why: self-heal the read table from the authoritative write tables. Seeds
  #      bypass the event bus, and long-running event drift can leave the read
  #      table out of sync — a single bootstrap query rebuilds every row from
  #      programs + program_sessions + program_staff_assignments + staff_members
  #      + aggregated participation_records counts.
  #
  # Design notes:
  #
  # * The SQL casts UUIDs to ::text so Postgrex returns them as string UUIDs
  #   (Ecto's :binary_id fields accept the string form directly on insert).
  # * Staff display uses first_name/last_name columns (staff_members has no
  #   display_name); we concatenate in Elixir via build_staff_name/2 to match
  #   the event-handler resolution path.
  # * Status comes back from SQL as text ("scheduled", "in_progress", ...);
  #   the schema is Ecto.Enum, so inserting via the schema module requires an
  #   atom — we convert via String.to_existing_atom/1 (safe: values are the
  #   fixed four enum members).
  # * Upsert preserves only identity-ish fields (session_id, inserted_at) and
  #   cover_staff_* (which cannot be derived from write tables yet — rebuilding
  #   would otherwise clobber whatever was evolved by a future cover handler).
  #   Everything else (status, counts, assigned staff) is intentionally
  #   refreshed, which is the whole point of rebuild/0.
  #
  # Outcome: {:ok, count} on success or {:error, reason} on DB failure; the
  #          caller decides whether to retry (handle_continue) or raise (rebuild).
  defp do_bootstrap do
    sql = """
    SELECT
      ps.id::text                            AS session_id,
      ps.program_id::text                    AS program_id,
      p.title                                AS program_title,
      p.provider_id::text                    AS provider_id,
      ps.session_date,
      ps.start_time,
      ps.end_time,
      ps.status::text                        AS status,
      psa.staff_member_id::text              AS current_assigned_staff_id,
      sm.first_name                          AS staff_first_name,
      sm.last_name                           AS staff_last_name,
      COALESCE(counts.checked_in, 0)         AS checked_in_count,
      COALESCE(counts.total, 0)              AS total_count
    FROM program_sessions ps
    JOIN programs p ON p.id = ps.program_id
    LEFT JOIN program_staff_assignments psa
           ON psa.program_id = ps.program_id
          AND psa.unassigned_at IS NULL
    LEFT JOIN staff_members sm
           ON sm.id = psa.staff_member_id
    LEFT JOIN (
      SELECT session_id,
             COUNT(*) FILTER (WHERE status IN ('checked_in','checked_out')) AS checked_in,
             COUNT(*) AS total
      FROM participation_records
      GROUP BY session_id
    ) counts ON counts.session_id = ps.id
    """

    case Repo.query(sql) do
      {:ok, %{rows: []}} ->
        {:ok, 0}

      {:ok, %{rows: rows}} ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        attrs_list =
          Enum.map(rows, fn [
                              session_id,
                              program_id,
                              program_title,
                              provider_id,
                              session_date,
                              start_time,
                              end_time,
                              status,
                              staff_id,
                              staff_first,
                              staff_last,
                              checked_in_count,
                              total_count
                            ] ->
            %{
              session_id: session_id,
              program_id: program_id,
              program_title: program_title,
              provider_id: provider_id,
              session_date: session_date,
              start_time: start_time,
              end_time: end_time,
              status: String.to_existing_atom(status),
              current_assigned_staff_id: staff_id,
              current_assigned_staff_name: build_staff_name(staff_first, staff_last),
              checked_in_count: checked_in_count,
              total_count: total_count,
              inserted_at: now,
              updated_at: now
            }
          end)

        {count, _} =
          Repo.insert_all(
            ProviderSessionDetailSchema,
            attrs_list,
            on_conflict: {:replace_all_except, [:session_id, :inserted_at, :cover_staff_id, :cover_staff_name]},
            conflict_target: [:session_id]
          )

        {:ok, count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Shared by session_started/completed/cancelled handlers. Missing rows
  # (unknown session_id) are logged per spec.
  defp update_status(session_id, status) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(d in ProviderSessionDetailSchema, where: d.session_id == ^session_id)
    |> Repo.update_all(set: [status: status, updated_at: now])
    |> warn_if_missing("status transition", session_id: session_id, target_status: status)
  end

  # Surfaces zero-row UPDATE results from event handlers so that events arriving
  # for unknown session_ids are observable rather than silently dropped.
  defp warn_if_missing({0, _}, event_name, metadata) do
    Logger.warning(
      "ProviderSessionDetails #{event_name} skipped: session not found",
      metadata
    )
  end

  defp warn_if_missing(_result, _event_name, _metadata), do: :ok

  # Single LEFT JOIN resolves program title/provider + (optionally) the earliest
  # active staff assignment's id + name. Returns nil fields when the program is
  # missing or has no active assignment.
  defp resolve_program_context(program_id) do
    sql = """
    SELECT p.title,
           p.provider_id,
           psa.staff_member_id,
           sm.first_name,
           sm.last_name
    FROM programs p
    LEFT JOIN program_staff_assignments psa
           ON psa.program_id = p.id
          AND psa.unassigned_at IS NULL
    LEFT JOIN staff_members sm ON sm.id = psa.staff_member_id
    WHERE p.id = $1
    ORDER BY psa.assigned_at ASC NULLS LAST
    LIMIT 1
    """

    case Repo.query(sql, [Ecto.UUID.dump!(program_id)]) do
      {:ok, %{rows: [[title, provider_id_bin, staff_id_bin, first_name, last_name]]}} ->
        %{
          program_title: title,
          provider_id: Ecto.UUID.cast!(provider_id_bin),
          staff_id: cast_uuid_or_nil(staff_id_bin),
          staff_name: build_staff_name(first_name, last_name)
        }

      _ ->
        Logger.warning("session_created: program not found", program_id: program_id)
        %{program_title: nil, provider_id: nil, staff_id: nil, staff_name: nil}
    end
  end

  defp cast_uuid_or_nil(nil), do: nil
  defp cast_uuid_or_nil(bin), do: Ecto.UUID.cast!(bin)

  # Trigger: staff_assigned_to_program handler needs the staff display name
  # Why: the integration event payload carries only ids — the name is looked up
  #      from the staff_members write table (source of truth); reusing
  #      build_staff_name/2 keeps the display convention identical to
  #      resolve_current_assigned_staff/1.
  # Outcome: "First Last" string, or nil if the staff row cannot be found
  defp lookup_staff_name(staff_id) do
    case Repo.query(
           "SELECT first_name, last_name FROM staff_members WHERE id = $1",
           [Ecto.UUID.dump!(staff_id)]
         ) do
      {:ok, %{rows: [[first_name, last_name]]}} -> build_staff_name(first_name, last_name)
      _ -> nil
    end
  end

  defp build_staff_name(nil, nil), do: nil
  defp build_staff_name(first, nil), do: first
  defp build_staff_name(nil, last), do: last
  defp build_staff_name(first, last), do: "#{first} #{last}"
end
