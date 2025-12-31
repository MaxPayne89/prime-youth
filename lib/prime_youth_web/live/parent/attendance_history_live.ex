defmodule PrimeYouthWeb.Parent.AttendanceHistoryLive do
  use PrimeYouthWeb, :live_view

  alias PrimeYouth.Attendance.Application.UseCases.GetAttendanceHistory
  alias PrimeYouth.Attendance.Application.UseCases.GetAttendanceRecord
  alias PrimeYouth.Identity
  alias PrimeYouth.Identity.Domain.Models.Child
  alias PrimeYouthWeb.Theme

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    parent_id = get_parent_id(socket)

    socket =
      socket
      |> assign(:page_title, gettext("Attendance History"))
      |> assign(:parent_id, parent_id)
      |> assign(:child_names, %{})
      |> assign(:children_ids, MapSet.new())
      # Uses stream for memory efficiency because:
      # - Potentially large, unbounded collection (all parent's history)
      # - Incremental updates (new check-ins prepended via PubSub)
      # - No need to enumerate in memory (LiveView handles rendering)
      |> stream(:attendance_records, [])

    if connected?(socket) do
      # Subscribe to standard attendance record topics to receive real-time updates
      # Events are broadcast to these aggregate-type topics by the use cases
      Phoenix.PubSub.subscribe(PrimeYouth.PubSub, "attendance_record:child_checked_in")
      Phoenix.PubSub.subscribe(PrimeYouth.PubSub, "attendance_record:child_checked_out")
      Phoenix.PubSub.subscribe(PrimeYouth.PubSub, "attendance_record:attendance_marked_absent")
    end

    {:ok, load_attendance_history(socket)}
  end

  # PubSub event handlers
  @impl true
  def handle_info(
        {:domain_event,
         %PrimeYouth.Shared.Domain.Events.DomainEvent{
           event_type: :child_checked_in,
           aggregate_id: record_id,
           payload: %{child_id: child_id}
         }},
        socket
      ) do
    socket =
      if child_belongs_to_parent?(child_id, socket) do
        load_and_insert_record(socket, record_id)
      else
        # Ignore events for other families' children
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:domain_event,
         %PrimeYouth.Shared.Domain.Events.DomainEvent{
           event_type: :child_checked_out,
           aggregate_id: record_id,
           payload: %{child_id: child_id}
         }},
        socket
      ) do
    socket =
      if child_belongs_to_parent?(child_id, socket) do
        load_and_update_record(socket, record_id)
      else
        # Ignore events for other families' children
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:domain_event,
         %PrimeYouth.Shared.Domain.Events.DomainEvent{
           event_type: :attendance_marked_absent,
           aggregate_id: record_id,
           payload: %{child_id: child_id}
         }},
        socket
      ) do
    socket =
      if child_belongs_to_parent?(child_id, socket) do
        load_and_update_record(socket, record_id)
      else
        # Ignore events for other families' children
        socket
      end

    {:noreply, socket}
  end

  # Private helper functions

  defp get_parent_id(socket) do
    case socket.assigns do
      %{current_scope: %{user: %{id: identity_id}}} ->
        case Identity.get_parent_by_identity(identity_id) do
          {:ok, parent} -> parent.id
          {:error, _reason} -> nil
        end

      _ ->
        nil
    end
  end

  defp child_belongs_to_parent?(child_id, socket) do
    MapSet.member?(socket.assigns.children_ids, child_id)
  end

  defp load_attendance_history(socket) do
    parent_id = socket.assigns.parent_id

    if parent_id do
      children = Identity.get_children(parent_id)
      attendance_records = GetAttendanceHistory.execute(:by_parent, parent_id)
      child_names = Map.new(children, fn child -> {child.id, Child.full_name(child)} end)
      children_ids = MapSet.new(children, fn child -> child.id end)

      socket
      |> assign(:child_names, child_names)
      |> assign(:children_ids, children_ids)
      |> stream(:attendance_records, attendance_records, reset: true)
      |> assign(:attendance_error, nil)
    else
      Logger.warning("[AttendanceHistoryLive.load_attendance_history] No parent_id available")

      socket
      |> stream(:attendance_records, [], reset: true)
      |> assign(:attendance_error, gettext("Failed to load attendance history"))
    end
  end

  defp load_and_insert_record(socket, record_id) do
    case GetAttendanceRecord.execute(record_id) do
      {:ok, record} ->
        stream_insert(socket, :attendance_records, record, at: 0)

      {:error, reason} ->
        Logger.error(
          "[AttendanceHistoryLive.load_and_insert_record] Failed to load record",
          record_id: record_id,
          reason: inspect(reason)
        )

        socket
    end
  end

  defp load_and_update_record(socket, record_id) do
    case GetAttendanceRecord.execute(record_id) do
      {:ok, record} ->
        stream_insert(socket, :attendance_records, record)

      {:error, reason} ->
        Logger.error(
          "[AttendanceHistoryLive.load_and_update_record] Failed to load record",
          record_id: record_id,
          reason: inspect(reason)
        )

        socket
    end
  end

  # Template helper functions

  defp format_date(nil), do: "N/A"
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%B %d, %Y")

  defp format_time(nil), do: "N/A"
  defp format_time(%Time{} = time), do: Calendar.strftime(time, "%I:%M %p")

  defp format_datetime(nil), do: "N/A"

  defp format_datetime(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end
end
