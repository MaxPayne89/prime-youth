defmodule KlassHeroWeb.Parent.ParticipationHistoryLive do
  use KlassHeroWeb, :live_view

  alias KlassHero.Identity
  alias KlassHero.Identity.Domain.Models.Child
  alias KlassHero.Participation
  alias KlassHeroWeb.Theme

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    parent_id = socket.assigns.current_scope.parent.id

    socket =
      socket
      |> assign(:page_title, gettext("Participation History"))
      |> assign(:parent_id, parent_id)
      |> assign(:child_names, %{})
      |> assign(:children_ids, MapSet.new())
      # Uses stream for memory efficiency because:
      # - Potentially large, unbounded collection (all parent's history)
      # - Incremental updates (new check-ins prepended via PubSub)
      # - No need to enumerate in memory (LiveView handles rendering)
      |> stream(:participation_records, [])

    if connected?(socket) do
      # Subscribe to standard participation record topics to receive real-time updates
      # Events are broadcast to these aggregate-type topics by the use cases
      Phoenix.PubSub.subscribe(KlassHero.PubSub, "participation_record:child_checked_in")
      Phoenix.PubSub.subscribe(KlassHero.PubSub, "participation_record:child_checked_out")

      Phoenix.PubSub.subscribe(
        KlassHero.PubSub,
        "participation_record:participation_marked_absent"
      )
    end

    {:ok, load_participation_history(socket)}
  end

  # PubSub event handler for participation record events
  @impl true
  def handle_info(
        {:domain_event,
         %KlassHero.Shared.Domain.Events.DomainEvent{
           event_type: event_type,
           aggregate_id: record_id,
           payload: %{child_id: child_id}
         }},
        socket
      )
      when event_type in [:child_checked_in, :child_checked_out, :participation_marked_absent] do
    socket =
      if child_belongs_to_parent?(child_id, socket) do
        # New check-ins are prepended (at: 0), updates replace in-place
        opts = if event_type == :child_checked_in, do: [at: 0], else: []
        load_and_stream_record(socket, record_id, opts)
      else
        socket
      end

    {:noreply, socket}
  end

  # Private helper functions

  defp child_belongs_to_parent?(child_id, socket) do
    MapSet.member?(socket.assigns.children_ids, child_id)
  end

  defp load_participation_history(socket) do
    parent_id = socket.assigns.parent_id

    if parent_id do
      children = Identity.get_children(parent_id)
      child_ids = Enum.map(children, & &1.id)

      {:ok, participation_records} =
        Participation.get_participation_history(%{child_ids: child_ids})

      child_names = Map.new(children, fn child -> {child.id, Child.full_name(child)} end)
      children_ids = Identity.get_child_ids_for_parent(parent_id)

      socket
      |> assign(:child_names, child_names)
      |> assign(:children_ids, children_ids)
      |> stream(:participation_records, participation_records, reset: true)
      |> assign(:participation_error, nil)
    else
      Logger.warning(
        "[ParticipationHistoryLive.load_participation_history] No parent_id available"
      )

      socket
      |> stream(:participation_records, [], reset: true)
      |> assign(:participation_error, gettext("Failed to load participation history"))
    end
  end

  defp load_and_stream_record(socket, record_id, opts) do
    case Participation.get_participation_record(record_id) do
      {:ok, record} ->
        stream_insert(socket, :participation_records, record, opts)

      {:error, reason} ->
        Logger.error(
          "[ParticipationHistoryLive] Failed to load record",
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
