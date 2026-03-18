defmodule KlassHeroWeb.Provider.SessionsLive do
  use KlassHeroWeb, :live_view

  alias KlassHero.Participation
  alias KlassHero.ProgramCatalog
  alias KlassHeroWeb.Theme

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    provider_id = socket.assigns.current_scope.provider.id
    selected_date = Date.utc_today()

    provider_programs = ProgramCatalog.list_programs_for_provider(provider_id)
    provider_program_ids = MapSet.new(provider_programs, & &1.id)

    socket =
      socket
      |> assign(:page_title, gettext("My Sessions"))
      |> assign(:provider_id, provider_id)
      |> assign(:selected_date, selected_date)
      |> assign(:provider_programs, provider_programs)
      |> assign(:provider_program_ids, provider_program_ids)
      |> assign(:show_modal, false)
      |> assign(:form, nil)
      |> stream(:sessions, [])

    if connected?(socket) do
      # Trigger: subscribing to generic event topics (not provider-specific)
      # Why: event system publishes to "aggregate:event_type" topics;
      #      provider-specific routing is a future enhancement
      # Outcome: handle_info receives all events, filters by provider's program IDs
      for topic <- [
            "participation:session_created",
            "participation:session_started",
            "participation:session_completed",
            "participation:child_checked_in"
          ] do
        Phoenix.PubSub.subscribe(KlassHero.PubSub, topic)
      end
    end

    {:ok, load_sessions(socket)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:show_modal, false)
    |> assign(:form, nil)
  end

  defp apply_action(socket, :new, _params) do
    programs = socket.assigns.provider_programs
    form_data = build_initial_form_data(socket.assigns.selected_date, programs)

    socket
    |> assign(:show_modal, true)
    |> assign(:form, to_form(form_data, as: :session))
  end

  @impl true
  def handle_event("change_date", %{"date" => date_string}, socket) do
    case Date.from_iso8601(date_string) do
      {:ok, new_date} ->
        socket =
          socket
          |> assign(:selected_date, new_date)
          |> load_sessions()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Invalid date format"))}
    end
  end

  @impl true
  def handle_event("start_session", %{"session_id" => session_id}, socket) do
    case Participation.start_session(session_id) do
      {:ok, _session} ->
        {:noreply, put_flash(socket, :info, gettext("Session started successfully"))}

      {:error, reason} ->
        Logger.error(
          "[SessionsLive.start_session] Failed to start session",
          session_id: session_id,
          reason: inspect(reason),
          provider_id: socket.assigns.provider_id
        )

        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Failed to start session: %{reason}", reason: inspect(reason))
         )}
    end
  end

  @impl true
  def handle_event("complete_session", %{"session_id" => session_id}, socket) do
    case Participation.complete_session(session_id) do
      {:ok, _session} ->
        {:noreply, put_flash(socket, :info, gettext("Session completed successfully"))}

      {:error, reason} ->
        Logger.error(
          "[SessionsLive.complete_session] Failed to complete session",
          session_id: session_id,
          reason: inspect(reason),
          provider_id: socket.assigns.provider_id
        )

        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Failed to complete session: %{reason}", reason: inspect(reason))
         )}
    end
  end

  @impl true
  def handle_event("validate_session", %{"session" => params}, socket) do
    params = maybe_prefill_from_program(params, socket.assigns.provider_programs)
    form = to_form(params, as: :session)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save_session", %{"session" => _params}, socket) do
    {:noreply, socket}
  end

  # PubSub event handlers — session lifecycle events
  @impl true
  def handle_info(
        {:domain_event,
         %KlassHero.Shared.Domain.Events.DomainEvent{
           event_type: event_type,
           aggregate_id: session_id,
           payload: %{program_id: program_id}
         }},
        socket
      )
      when event_type in [:session_started, :session_completed, :session_created] do
    # Trigger: generic topic delivers events for ALL providers' sessions
    # Why: we only subscribe to generic topics (not provider-specific)
    # Outcome: ignore events for programs not belonging to this provider
    if MapSet.member?(socket.assigns.provider_program_ids, program_id) do
      {:noreply, update_session_in_stream(socket, session_id)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(
        {:domain_event,
         %KlassHero.Shared.Domain.Events.DomainEvent{
           event_type: :child_checked_in,
           payload: %{session_id: session_id}
         }},
        socket
      ) do
    # Trigger: child_checked_in payload lacks program_id
    # Why: event only carries session_id and child_id
    # Outcome: attempt fetch — if session not in stream, stream_insert is harmless
    {:noreply, update_session_in_stream(socket, session_id)}
  end

  # Private helper functions

  defp build_initial_form_data(selected_date, _programs) do
    %{
      "program_id" => "",
      "session_date" => Date.to_iso8601(selected_date),
      "start_time" => "",
      "end_time" => "",
      "location" => "",
      "notes" => "",
      "max_capacity" => ""
    }
  end

  defp load_sessions(socket) do
    provider_id = socket.assigns.provider_id
    selected_date = socket.assigns.selected_date

    {:ok, sessions} = Participation.list_provider_sessions(provider_id, selected_date)

    socket
    |> stream(:sessions, sessions, reset: true)
    |> assign(:sessions_error, nil)
  end

  defp maybe_prefill_from_program(params, programs) do
    program_id = params["program_id"]

    case Enum.find(programs, &(&1.id == program_id)) do
      nil ->
        params

      program ->
        # Trigger: provider selected a program from the dropdown
        # Why: pre-fill time/location from program defaults to reduce repetitive typing
        # Outcome: form fields populated; provider can override any value
        params
        |> maybe_set_default("start_time", format_time(program.meeting_start_time))
        |> maybe_set_default("end_time", format_time(program.meeting_end_time))
        |> maybe_set_default("location", program.location || "")
    end
  end

  # Only set if the field is currently empty — don't overwrite provider edits
  defp maybe_set_default(params, key, default) do
    if params[key] in [nil, ""] do
      Map.put(params, key, default)
    else
      params
    end
  end

  defp format_time(nil), do: ""
  defp format_time(%Time{} = time), do: Calendar.strftime(time, "%H:%M")

  defp update_session_in_stream(socket, session_id) do
    case Participation.get_session_with_roster(session_id) do
      {:ok, %{session: session}} ->
        stream_insert(socket, :sessions, session)

      {:error, reason} ->
        Logger.error(
          "[SessionsLive.update_session_in_stream] Failed to fetch session",
          session_id: session_id,
          reason: inspect(reason)
        )

        socket
    end
  end
end
