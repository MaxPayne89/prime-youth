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
    {:ok, %{bootstrapped: false}, {:continue, :bootstrap}}
  end

  @impl true
  def handle_continue(:bootstrap, state) do
    # implementation comes in Task 13
    {:noreply, %{state | bootstrapped: true}}
  end

  @impl true
  def handle_call(:rebuild, _from, state) do
    # implementation comes in Task 13
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

  @impl true
  def handle_info({:integration_event, _event}, state) do
    # remaining event clauses come in Tasks 10–12; final catch-all arrives in Task 12
    {:noreply, state}
  end

  defp project_session_created(%{
         session_id: session_id,
         program_id: program_id,
         session_date: session_date,
         start_time: start_time,
         end_time: end_time
       }) do
    {program_title, provider_id} = resolve_program(program_id)
    {staff_id, staff_name} = resolve_current_assigned_staff(program_id)

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

  # Trigger: any of the session_started/completed/cancelled handlers
  # Why: the three status-transition handlers share the same update shape;
  #      centralising keeps the transitions uniform and easy to audit
  # Outcome: the row's status column (and updated_at) is updated in place.
  #          If the session row is missing (unknown session_id), a warning is
  #          logged per spec.
  defp update_status(session_id, status) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {updated, _} =
      from(d in ProviderSessionDetailSchema, where: d.session_id == ^session_id)
      |> Repo.update_all(set: [status: status, updated_at: now])

    if updated == 0 do
      Logger.warning("ProviderSessionDetails status transition skipped: session not found",
        session_id: session_id,
        target_status: status
      )
    end

    :ok
  end

  # Trigger: session_created handler needs program_title + provider_id
  # Why: the programs write table is the source of truth; reading it directly
  #      avoids adding a new ACL port just for two fields. Symmetric with the
  #      bootstrap query that will live in this module (Task 13).
  # Outcome: {title, provider_id_string} tuple, or {nil, nil} on miss
  defp resolve_program(program_id) do
    case Repo.query(
           "SELECT title, provider_id FROM programs WHERE id = $1",
           [Ecto.UUID.dump!(program_id)]
         ) do
      {:ok, %{rows: [[title, provider_id_bin]]}} ->
        {title, Ecto.UUID.cast!(provider_id_bin)}

      _ ->
        Logger.warning("session_created: program not found", program_id: program_id)
        {nil, nil}
    end
  end

  # Trigger: session_created handler needs the currently assigned staff
  # Why: display at session creation uses the program's active assignment
  # Outcome: {staff_id_string, "First Last"} tuple, or {nil, nil} if no assignment
  defp resolve_current_assigned_staff(program_id) do
    case Repo.query(
           """
           SELECT psa.staff_member_id, sm.first_name, sm.last_name
           FROM program_staff_assignments psa
           JOIN staff_members sm ON sm.id = psa.staff_member_id
           WHERE psa.program_id = $1 AND psa.unassigned_at IS NULL
           ORDER BY psa.assigned_at ASC
           LIMIT 1
           """,
           [Ecto.UUID.dump!(program_id)]
         ) do
      {:ok, %{rows: [[staff_id_bin, first_name, last_name]]}} ->
        {Ecto.UUID.cast!(staff_id_bin), build_staff_name(first_name, last_name)}

      _ ->
        {nil, nil}
    end
  end

  defp build_staff_name(nil, nil), do: nil
  defp build_staff_name(first, nil), do: first
  defp build_staff_name(nil, last), do: last
  defp build_staff_name(first, last), do: "#{first} #{last}"
end
