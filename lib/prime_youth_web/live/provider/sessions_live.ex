defmodule PrimeYouthWeb.Provider.SessionsLive do
  use PrimeYouthWeb, :live_view

  alias PrimeYouth.Attendance.Application.UseCases.CompleteSession
  alias PrimeYouth.Attendance.Application.UseCases.GetSessionWithRoster
  alias PrimeYouth.Attendance.Application.UseCases.ListProviderSessions
  alias PrimeYouth.Attendance.Application.UseCases.StartSession
  alias PrimeYouthWeb.Theme

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    provider_id = get_provider_id(socket)
    selected_date = Date.utc_today()

    socket =
      socket
      |> assign(:page_title, "My Sessions")
      |> assign(:provider_id, provider_id)
      |> assign(:selected_date, selected_date)
      |> stream(:sessions, [])

    if connected?(socket) do
      Phoenix.PubSub.subscribe(
        PrimeYouth.PubSub,
        "attendance:provider:#{provider_id}"
      )
    end

    {:ok, load_sessions(socket)}
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
        {:noreply, put_flash(socket, :error, "Invalid date format")}
    end
  end

  @impl true
  def handle_event("start_session", %{"session_id" => session_id}, socket) do
    case StartSession.execute(session_id) do
      {:ok, _session} ->
        {:noreply, put_flash(socket, :info, "Session started successfully")}

      {:error, reason} ->
        Logger.error(
          "[SessionsLive.start_session] Failed to start session",
          session_id: session_id,
          reason: inspect(reason),
          provider_id: socket.assigns.provider_id
        )

        {:noreply, put_flash(socket, :error, "Failed to start session: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("complete_session", %{"session_id" => session_id}, socket) do
    case CompleteSession.execute(session_id) do
      {:ok, _session} ->
        {:noreply, put_flash(socket, :info, "Session completed successfully")}

      {:error, reason} ->
        Logger.error(
          "[SessionsLive.complete_session] Failed to complete session",
          session_id: session_id,
          reason: inspect(reason),
          provider_id: socket.assigns.provider_id
        )

        {:noreply, put_flash(socket, :error, "Failed to complete session: #{inspect(reason)}")}
    end
  end

  # PubSub event handlers
  @impl true
  def handle_info(
        %PrimeYouth.Shared.Domain.Events.DomainEvent{
          event_type: :session_started,
          aggregate_id: session_id
        },
        socket
      ) do
    socket = update_session_in_stream(socket, session_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %PrimeYouth.Shared.Domain.Events.DomainEvent{
          event_type: :session_completed,
          aggregate_id: session_id
        },
        socket
      ) do
    socket = update_session_in_stream(socket, session_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %PrimeYouth.Shared.Domain.Events.DomainEvent{
          event_type: :child_checked_in,
          payload: %{session_id: session_id}
        },
        socket
      ) do
    socket = update_session_in_stream(socket, session_id)
    {:noreply, socket}
  end

  # Private helper functions

  defp get_provider_id(socket) do
    case socket.assigns do
      %{current_scope: %{user: %{id: user_id}}} -> user_id
      _ -> nil
    end
  end

  defp load_sessions(socket) do
    provider_id = socket.assigns.provider_id
    selected_date = socket.assigns.selected_date

    case ListProviderSessions.execute(provider_id, selected_date) do
      {:ok, sessions} ->
        socket
        |> stream(:sessions, sessions, reset: true)
        |> assign(:sessions_error, nil)

      {:error, reason} ->
        Logger.error(
          "[SessionsLive.load_sessions] Failed to load sessions",
          provider_id: provider_id,
          selected_date: selected_date,
          reason: inspect(reason)
        )

        socket
        |> stream(:sessions, [], reset: true)
        |> assign(:sessions_error, "Failed to load sessions")
    end
  end

  defp update_session_in_stream(socket, session_id) do
    case GetSessionWithRoster.execute(session_id) do
      {:ok, session} ->
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
