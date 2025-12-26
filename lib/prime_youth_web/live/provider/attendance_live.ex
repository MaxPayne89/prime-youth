defmodule PrimeYouthWeb.Provider.AttendanceLive do
  use PrimeYouthWeb, :live_view

  alias PrimeYouth.Attendance.Application.UseCases.BulkCheckIn
  alias PrimeYouth.Attendance.Application.UseCases.GetSessionWithRoster
  alias PrimeYouth.Attendance.Application.UseCases.RecordCheckIn
  alias PrimeYouth.Attendance.Application.UseCases.RecordCheckOut
  alias PrimeYouthWeb.Theme

  require Logger

  @impl true
  def mount(%{"session_id" => session_id}, _session, socket) do
    provider_id = get_provider_id(socket)

    socket =
      socket
      |> assign(:page_title, "Manage Attendance")
      |> assign(:session_id, session_id)
      |> assign(:provider_id, provider_id)
      |> assign(:session, nil)
      # Uses regular assign (not stream) because:
      # - Small, bounded collection (records for single session)
      # - Need to filter/search records (Enum.find, Enum.filter)
      # - Full replacement on updates (no incremental changes)
      |> assign(:attendance_records, [])
      |> assign(:form, nil)
      |> assign(:checkout_form_expanded, nil)
      |> assign(:checkout_forms, %{})

    if connected?(socket) do
      # Subscribe to attendance record events for real-time UI updates
      Phoenix.PubSub.subscribe(PrimeYouth.PubSub, "attendance_record:child_checked_in")
      Phoenix.PubSub.subscribe(PrimeYouth.PubSub, "attendance_record:child_checked_out")
      Phoenix.PubSub.subscribe(PrimeYouth.PubSub, "attendance_record:attendance_marked_absent")
    end

    {:ok, load_session_data(socket)}
  end

  @impl true
  def handle_event("submit_attendance", params, socket) do
    checked_ids = Map.get(params, "attendance", %{}) |> Map.get("checked_in", [])

    record_ids =
      socket.assigns.attendance_records
      |> Enum.filter(fn record -> to_string(record.id) in checked_ids end)
      |> Enum.map(& &1.id)

    case BulkCheckIn.execute(
           socket.assigns.session_id,
           record_ids,
           socket.assigns.provider_id
         ) do
      {:ok, _result} ->
        {:noreply,
         socket
         |> put_flash(:info, "Children checked in successfully")
         |> load_session_data()}

      {:error, :empty_record_ids} ->
        {:noreply, put_flash(socket, :error, "Please select at least one child to check in")}

      {:error, reason} ->
        Logger.error(
          "[AttendanceLive.submit_attendance] Failed to bulk check in",
          session_id: socket.assigns.session_id,
          reason: inspect(reason)
        )

        {:noreply, put_flash(socket, :error, "Failed to check in children: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("check_in", %{"id" => record_id}, socket) do
    record = find_attendance_record(socket, record_id)

    case record do
      nil ->
        {:noreply, put_flash(socket, :error, "Record not found")}

      record ->
        case RecordCheckIn.execute(
               socket.assigns.session_id,
               record.child_id,
               socket.assigns.provider_id
             ) do
          {:ok, _record} ->
            {:noreply,
             socket
             |> put_flash(:info, "Child checked in successfully")
             |> load_session_data()}

          {:error, reason} ->
            Logger.error(
              "[AttendanceLive.check_in] Failed to check in",
              record_id: record_id,
              child_id: record.child_id,
              reason: inspect(reason)
            )

            {:noreply, put_flash(socket, :error, "Failed to check in: #{inspect(reason)}")}
        end
    end
  end

  @impl true
  def handle_event("expand_checkout_form", %{"id" => record_id}, socket) do
    form = to_form(%{"notes" => ""}, as: "checkout")

    socket =
      socket
      |> assign(:checkout_form_expanded, record_id)
      |> assign(:checkout_forms, Map.put(socket.assigns.checkout_forms, record_id, form))

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_checkout", %{"id" => record_id}, socket) do
    socket =
      socket
      |> assign(:checkout_form_expanded, nil)
      |> assign(:checkout_forms, Map.delete(socket.assigns.checkout_forms, record_id))

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_checkout_notes", %{"id" => record_id, "checkout" => %{"notes" => notes}}, socket) do
    current_forms = socket.assigns.checkout_forms
    updated_form = to_form(%{"notes" => notes}, as: "checkout")

    socket = assign(socket, :checkout_forms, Map.put(current_forms, record_id, updated_form))

    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm_checkout", %{"id" => record_id, "checkout" => params}, socket) do
    record = find_attendance_record(socket, record_id)
    notes = Map.get(params, "notes", "") |> String.trim()
    notes = if notes == "", do: nil, else: notes

    case record do
      nil ->
        {:noreply, put_flash(socket, :error, "Record not found")}

      record ->
        case RecordCheckOut.execute(
               socket.assigns.session_id,
               record.child_id,
               socket.assigns.provider_id,
               notes
             ) do
          {:ok, _record} ->
            {:noreply,
             socket
             |> put_flash(:info, "Child checked out successfully")
             |> assign(:checkout_form_expanded, nil)
             |> assign(:checkout_forms, Map.delete(socket.assigns.checkout_forms, record_id))
             |> load_session_data()}

          {:error, reason} ->
            Logger.error(
              "[AttendanceLive.confirm_checkout] Failed to check out",
              record_id: record_id,
              child_id: record.child_id,
              reason: inspect(reason)
            )

            {:noreply, put_flash(socket, :error, "Failed to check out: #{inspect(reason)}")}
        end
    end
  end

  # PubSub event handlers
  @impl true
  def handle_info(
        {:domain_event,
         %PrimeYouth.Shared.Domain.Events.DomainEvent{
           event_type: :child_checked_in,
           aggregate_id: record_id
         }},
        socket
      ) do
    socket = update_attendance_record(socket, record_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:domain_event,
         %PrimeYouth.Shared.Domain.Events.DomainEvent{
           event_type: :child_checked_out,
           aggregate_id: record_id
         }},
        socket
      ) do
    socket = update_attendance_record(socket, record_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:domain_event,
         %PrimeYouth.Shared.Domain.Events.DomainEvent{
           event_type: :attendance_marked_absent,
           aggregate_id: record_id
         }},
        socket
      ) do
    socket = update_attendance_record(socket, record_id)
    {:noreply, socket}
  end

  # Private helper functions

  defp load_session_data(socket) do
    session_id = socket.assigns.session_id

    case GetSessionWithRoster.execute_enriched(session_id) do
      {:ok, session} ->
        socket
        |> assign(:session, session)
        |> assign(:attendance_records, session.attendance_records || [])
        |> assign(:form, to_form(%{}, as: :attendance))
        |> assign(:session_error, nil)

      {:error, :not_found} ->
        Logger.warning(
          "[AttendanceLive.load_session_data] Session not found",
          session_id: session_id
        )

        socket
        |> put_flash(:error, "Session not found")
        |> push_navigate(to: ~p"/provider/sessions")

      {:error, reason} ->
        Logger.error(
          "[AttendanceLive.load_session_data] Failed to load session data",
          session_id: session_id,
          reason: inspect(reason)
        )

        socket
        |> assign(:session_error, "Failed to load session data")
    end
  end

  defp update_attendance_record(socket, record_id) do
    case GetSessionWithRoster.execute_enriched(socket.assigns.session_id) do
      {:ok, session} ->
        socket
        |> assign(:session, session)
        |> assign(:attendance_records, session.attendance_records || [])

      {:error, reason} ->
        Logger.error(
          "[AttendanceLive.update_attendance_record] Failed to refresh session",
          session_id: socket.assigns.session_id,
          record_id: record_id,
          reason: inspect(reason)
        )

        socket
    end
  end

  defp get_provider_id(socket) do
    case socket.assigns do
      %{current_scope: %{user: %{id: user_id}}} -> user_id
      _ -> nil
    end
  end

  defp find_attendance_record(socket, record_id) do
    Enum.find(socket.assigns.attendance_records, fn record ->
      to_string(record.id) == record_id
    end)
  end
end
