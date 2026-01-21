defmodule KlassHeroWeb.Provider.ParticipationLive do
  use KlassHeroWeb, :live_view

  alias KlassHero.Participation
  alias KlassHeroWeb.Theme

  require Logger

  @impl true
  def mount(%{"session_id" => session_id}, _session, socket) do
    provider_id = socket.assigns.current_scope.provider.id

    socket =
      socket
      |> assign(:page_title, gettext("Manage Participation"))
      |> assign(:session_id, session_id)
      |> assign(:provider_id, provider_id)
      |> assign(:session, nil)
      # Uses regular assign (not stream) because:
      # - Small, bounded collection (records for single session)
      # - Need to filter/search records (Enum.find, Enum.filter)
      # - Full replacement on updates (no incremental changes)
      |> assign(:participation_records, [])
      |> assign(:checkout_form_expanded, nil)
      |> assign(:checkout_forms, %{})

    if connected?(socket) do
      # Subscribe to participation record events for real-time UI updates
      Phoenix.PubSub.subscribe(KlassHero.PubSub, "participation_record:child_checked_in")
      Phoenix.PubSub.subscribe(KlassHero.PubSub, "participation_record:child_checked_out")

      Phoenix.PubSub.subscribe(
        KlassHero.PubSub,
        "participation_record:participation_marked_absent"
      )
    end

    {:ok, load_session_data(socket)}
  end

  @impl true
  def handle_event("check_in", %{"id" => record_id}, socket) do
    record = find_participation_record(socket, record_id)

    case record do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Record not found"))}

      record ->
        case Participation.record_check_in(%{
               record_id: record.id,
               checked_in_by: socket.assigns.provider_id
             }) do
          {:ok, _record} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Child checked in successfully"))
             |> load_session_data()}

          {:error, reason} ->
            Logger.error(
              "[ParticipationLive.check_in] Failed to check in",
              record_id: record_id,
              child_id: record.child_id,
              reason: inspect(reason)
            )

            {:noreply,
             put_flash(
               socket,
               :error,
               gettext("Failed to check in: %{reason}", reason: inspect(reason))
             )}
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
  def handle_event(
        "update_checkout_notes",
        %{"id" => record_id, "checkout" => %{"notes" => notes}},
        socket
      ) do
    current_forms = socket.assigns.checkout_forms
    updated_form = to_form(%{"notes" => notes}, as: "checkout")

    socket = assign(socket, :checkout_forms, Map.put(current_forms, record_id, updated_form))

    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm_checkout", %{"id" => record_id, "checkout" => params}, socket) do
    record = find_participation_record(socket, record_id)
    notes = Map.get(params, "notes")

    case record do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Record not found"))}

      record ->
        case Participation.record_check_out(%{
               record_id: record.id,
               checked_out_by: socket.assigns.provider_id,
               notes: notes
             }) do
          {:ok, _record} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Child checked out successfully"))
             |> assign(:checkout_form_expanded, nil)
             |> assign(:checkout_forms, Map.delete(socket.assigns.checkout_forms, record_id))
             |> load_session_data()}

          {:error, reason} ->
            Logger.error(
              "[ParticipationLive.confirm_checkout] Failed to check out",
              record_id: record_id,
              child_id: record.child_id,
              reason: inspect(reason)
            )

            {:noreply,
             put_flash(
               socket,
               :error,
               gettext("Failed to check out: %{reason}", reason: inspect(reason))
             )}
        end
    end
  end

  # PubSub event handlers
  @impl true
  def handle_info(
        {:domain_event,
         %KlassHero.Shared.Domain.Events.DomainEvent{
           event_type: :child_checked_in,
           aggregate_id: record_id
         }},
        socket
      ) do
    socket = update_participation_record(socket, record_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:domain_event,
         %KlassHero.Shared.Domain.Events.DomainEvent{
           event_type: :child_checked_out,
           aggregate_id: record_id
         }},
        socket
      ) do
    socket = update_participation_record(socket, record_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:domain_event,
         %KlassHero.Shared.Domain.Events.DomainEvent{
           event_type: :participation_marked_absent,
           aggregate_id: record_id
         }},
        socket
      ) do
    socket = update_participation_record(socket, record_id)
    {:noreply, socket}
  end

  # Private helper functions

  defp load_session_data(socket) do
    session_id = socket.assigns.session_id

    case Participation.get_session_with_roster_enriched(session_id) do
      {:ok, session} ->
        socket
        |> assign(:session, session)
        |> assign(:participation_records, session.participation_records || [])
        |> assign(:session_error, nil)

      {:error, :not_found} ->
        Logger.warning(
          "[ParticipationLive.load_session_data] Session not found",
          session_id: session_id
        )

        socket
        |> put_flash(:error, gettext("Session not found"))
        |> push_navigate(to: ~p"/provider/sessions")

      {:error, reason} ->
        Logger.error(
          "[ParticipationLive.load_session_data] Failed to load session data",
          session_id: session_id,
          reason: inspect(reason)
        )

        socket
        |> assign(:session_error, gettext("Failed to load session data"))
    end
  end

  defp update_participation_record(socket, record_id) do
    case Participation.get_session_with_roster_enriched(socket.assigns.session_id) do
      {:ok, session} ->
        socket
        |> assign(:session, session)
        |> assign(:participation_records, session.participation_records || [])

      {:error, reason} ->
        Logger.error(
          "[ParticipationLive.update_participation_record] Failed to refresh session",
          session_id: socket.assigns.session_id,
          record_id: record_id,
          reason: inspect(reason)
        )

        socket
    end
  end

  defp find_participation_record(socket, record_id) do
    Enum.find(socket.assigns.participation_records, fn record ->
      to_string(record.id) == record_id
    end)
  end
end
