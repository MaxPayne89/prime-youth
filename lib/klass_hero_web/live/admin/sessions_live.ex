defmodule KlassHeroWeb.Admin.SessionsLive do
  @moduledoc """
  Admin dashboard for participation sessions.

  Two modes:
  - `:today` (default) — shows all sessions for today
  - `:filter` — shows filtered sessions across any date range
  """

  use KlassHeroWeb, :live_view

  alias KlassHero.Participation
  alias KlassHeroWeb.Theme

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:fluid?, false)
     |> assign(:live_resource, nil)
     |> assign(:mode, :today)
     |> assign(:filters, %{})
     |> assign(:page_title, gettext("Sessions"))
     |> assign(:session_statuses, Participation.session_statuses())}
  end

  @impl true
  def handle_params(params, uri, socket) do
    current_url = URI.parse(uri).path

    socket =
      socket
      |> assign(:current_url, current_url)
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    # Use case defaults to today when no date filter provided
    sessions = Participation.list_admin_sessions(%{})
    stream(socket, :sessions, sessions, reset: true)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    case Participation.get_session_with_roster_enriched(id) do
      {:ok, session} ->
        socket
        |> assign(:session, session)
        |> assign(:editing_record_id, nil)
        |> assign(:correction_form, nil)

      {:error, :not_found} ->
        socket
        |> put_flash(:error, gettext("Session not found"))
        |> push_navigate(to: ~p"/admin/sessions")
    end
  end

  @impl true
  def handle_event("switch_mode", %{"mode" => mode}, socket) do
    mode = String.to_existing_atom(mode)

    socket =
      case mode do
        :today ->
          sessions = Participation.list_admin_sessions(%{date: Date.utc_today()})

          socket
          |> assign(:mode, :today)
          |> assign(:filters, %{})
          |> stream(:sessions, sessions, reset: true)

        :filter ->
          assign(socket, :mode, :filter)
      end

    {:noreply, socket}
  end

  def handle_event("apply_filters", params, socket) do
    filters = build_filters_from_params(params)
    sessions = Participation.list_admin_sessions(filters)

    socket =
      socket
      |> assign(:filters, filters)
      |> stream(:sessions, sessions, reset: true)

    {:noreply, socket}
  end

  def handle_event("open_correction", %{"record-id" => record_id}, socket) do
    {:noreply,
     socket
     |> assign(:editing_record_id, record_id)
     |> assign(:correction_form, to_form(%{"reason" => ""}, as: :correction))}
  end

  def handle_event("cancel_correction", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_record_id, nil)
     |> assign(:correction_form, nil)}
  end

  def handle_event("save_correction", %{"correction" => correction_params}, socket) do
    record_id = socket.assigns.editing_record_id

    base_params =
      %{record_id: record_id, reason: correction_params["reason"]}
      |> maybe_put_status(correction_params)

    with {:ok, params} <-
           maybe_put_time(base_params, :check_in_at, correction_params["check_in_at"]),
         {:ok, params} <- maybe_put_time(params, :check_out_at, correction_params["check_out_at"]),
         {:ok, _corrected} <- Participation.correct_attendance(params),
         {:ok, session} <-
           Participation.get_session_with_roster_enriched(socket.assigns.session.id) do
      {:noreply,
       socket
       |> assign(:session, session)
       |> assign(:editing_record_id, nil)
       |> assign(:correction_form, nil)
       |> put_flash(:info, gettext("Attendance corrected successfully"))}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_message(reason))}
    end
  end

  # -- Private Helpers --

  defp build_filters_from_params(params) do
    %{}
    |> maybe_add_filter(:provider_id, params["provider_id"])
    |> maybe_add_filter(:program_id, params["program_id"])
    |> maybe_add_filter(:status, parse_status(params["status"]))
    |> maybe_add_date_filter(params)
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, _key, ""), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  defp maybe_add_date_filter(filters, %{"date_from" => from, "date_to" => to})
       when from != "" and to != "" do
    Map.merge(filters, %{
      date_from: Date.from_iso8601!(from),
      date_to: Date.from_iso8601!(to)
    })
  end

  # No date range provided in filter mode — use case defaults to today
  defp maybe_add_date_filter(filters, _params), do: filters

  defp parse_status(""), do: nil
  defp parse_status(nil), do: nil
  defp parse_status(status), do: String.to_existing_atom(status)

  defp maybe_put_status(params, %{"status" => ""}), do: params

  defp maybe_put_status(params, %{"status" => s}),
    do: Map.put(params, :status, String.to_existing_atom(s))

  defp maybe_put_status(params, _), do: params

  defp maybe_put_time(params, _key, nil), do: {:ok, params}
  defp maybe_put_time(params, _key, ""), do: {:ok, params}

  defp maybe_put_time(params, key, time_string) do
    # Trigger: datetime-local inputs submit "YYYY-MM-DDTHH:MM" (no timezone, no seconds)
    # Why: NaiveDateTime.from_iso8601 requires seconds; datetime-local omits them
    # Outcome: normalize by appending ":00", parse as NaiveDateTime, convert to UTC
    normalized = normalize_datetime_local(time_string)

    case NaiveDateTime.from_iso8601(normalized) do
      {:ok, ndt} -> {:ok, Map.put(params, key, DateTime.from_naive!(ndt, "Etc/UTC"))}
      _ -> {:error, :invalid_time}
    end
  end

  # Trigger: HTML datetime-local inputs submit "YYYY-MM-DDTHH:MM" (16 chars, no seconds)
  # Why: NaiveDateTime.from_iso8601/1 requires "YYYY-MM-DDTHH:MM:SS" format
  # Outcome: appends ":00" to match the expected format
  defp normalize_datetime_local(s) when byte_size(s) == 16, do: s <> ":00"
  defp normalize_datetime_local(s), do: s

  defp error_message(:reason_required), do: gettext("A reason is required for corrections")
  defp error_message(:no_changes), do: gettext("No changes detected")
  defp error_message(:not_found), do: gettext("Record not found")

  defp error_message(:stale_data),
    do: gettext("Record was modified by someone else. Please refresh.")

  defp error_message(:check_out_requires_check_in),
    do: gettext("Cannot check out without a check-in")

  defp error_message(:check_in_must_precede_check_out),
    do: gettext("Check-in time must be before check-out time")

  defp error_message(:invalid_time), do: gettext("Invalid time format")

  defp error_message(_), do: gettext("An error occurred")

  # -- View Helpers (used in template) --

  defp status_badge_class(:scheduled), do: "badge-info"
  defp status_badge_class(:in_progress), do: "badge-success"
  defp status_badge_class(:completed), do: "badge-secondary"
  defp status_badge_class(:cancelled), do: "badge-error"
  defp status_badge_class(_), do: ""

  defp record_status_class(:registered), do: "badge-ghost"
  defp record_status_class(:checked_in), do: "badge-success"
  defp record_status_class(:checked_out), do: "badge-secondary"
  defp record_status_class(:absent), do: "badge-error"
  defp record_status_class(_), do: ""

  defp humanize_status(:in_progress), do: gettext("In Progress")
  defp humanize_status(:checked_in), do: gettext("Checked In")
  defp humanize_status(:checked_out), do: gettext("Checked Out")
  defp humanize_status(status), do: status |> to_string() |> String.capitalize()

  defp format_time(nil), do: "—"
  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%H:%M")

  defp format_datetime_local(nil), do: ""
  defp format_datetime_local(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%dT%H:%M")

  defp note_badge(record) do
    notes = Map.get(record, :behavioral_notes, [])

    cond do
      notes == [] ->
        "—"

      Enum.any?(notes, &(&1.status == :approved)) ->
        gettext("Approved")

      Enum.any?(notes, &(&1.status == :pending_approval)) ->
        gettext("Pending")

      true ->
        "—"
    end
  end
end
