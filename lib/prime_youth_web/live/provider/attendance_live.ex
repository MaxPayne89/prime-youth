defmodule PrimeYouthWeb.Provider.AttendanceLive do
  use PrimeYouthWeb, :live_view

  alias PrimeYouth.Attendance.Application.UseCases.GetSessionWithRoster
  alias PrimeYouth.Attendance.Application.UseCases.RecordCheckIn
  alias PrimeYouth.Attendance.Application.UseCases.RecordCheckOut
  alias PrimeYouth.Attendance.Application.UseCases.SubmitAttendance
  alias PrimeYouth.Family.Application.UseCases.GetChildren
  alias PrimeYouth.Family.Domain.Models.Child
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
      |> assign(:attendance_records, [])
      |> assign(:child_names, %{})
      |> assign(:form, nil)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(
        PrimeYouth.PubSub,
        "attendance:session:#{session_id}"
      )
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

    case SubmitAttendance.execute(
           socket.assigns.session_id,
           record_ids,
           socket.assigns.provider_id
         ) do
      {:ok, _result} ->
        {:noreply,
         socket
         |> put_flash(:info, "Attendance submitted successfully")
         |> load_session_data()}

      {:error, :empty_record_ids} ->
        {:noreply, put_flash(socket, :error, "Please select at least one record to submit")}

      {:error, reason} ->
        Logger.error(
          "[AttendanceLive.submit_attendance] Failed to submit attendance",
          session_id: socket.assigns.session_id,
          reason: inspect(reason)
        )

        {:noreply, put_flash(socket, :error, "Failed to submit attendance: #{inspect(reason)}")}
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
            {:noreply, put_flash(socket, :info, "Child checked in successfully")}

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
  def handle_event("check_out", %{"id" => record_id}, socket) do
    record = find_attendance_record(socket, record_id)

    case record do
      nil ->
        {:noreply, put_flash(socket, :error, "Record not found")}

      record ->
        case RecordCheckOut.execute(
               socket.assigns.session_id,
               record.child_id,
               socket.assigns.provider_id
             ) do
          {:ok, _record} ->
            {:noreply, put_flash(socket, :info, "Child checked out successfully")}

          {:error, reason} ->
            Logger.error(
              "[AttendanceLive.check_out] Failed to check out",
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
        %PrimeYouth.Shared.Domain.Events.DomainEvent{
          event_type: :child_checked_in,
          aggregate_id: record_id
        },
        socket
      ) do
    socket = update_attendance_record(socket, record_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %PrimeYouth.Shared.Domain.Events.DomainEvent{
          event_type: :child_checked_out,
          aggregate_id: record_id
        },
        socket
      ) do
    socket = update_attendance_record(socket, record_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %PrimeYouth.Shared.Domain.Events.DomainEvent{
          event_type: :attendance_marked_absent,
          aggregate_id: record_id
        },
        socket
      ) do
    socket = update_attendance_record(socket, record_id)
    {:noreply, socket}
  end

  # Private helper functions

  defp load_session_data(socket) do
    session_id = socket.assigns.session_id

    with {:ok, session} <- GetSessionWithRoster.execute(session_id),
         {:ok, children} <- GetChildren.execute(:simple) do
      child_names = Map.new(children, fn child -> {child.id, Child.full_name(child)} end)

      socket
      |> assign(:session, session)
      |> assign(:attendance_records, session.attendance_records || [])
      |> assign(:child_names, child_names)
      |> assign(:form, to_form(%{}, as: :attendance))
      |> assign(:session_error, nil)
    else
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
    case GetSessionWithRoster.execute(socket.assigns.session_id) do
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
