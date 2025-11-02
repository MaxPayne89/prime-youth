defmodule PrimeYouthWeb.ProgramLive.Index do
  @moduledoc """
  LiveView for browsing and discovering programs in the marketplace.

  Provides filtering, searching, and pagination capabilities for program discovery.
  """

  use PrimeYouthWeb, :live_view

  alias PrimeYouth.ProgramCatalog.UseCases.BrowsePrograms

  @impl true
  def mount(_params, _session, socket) do
    programs = BrowsePrograms.execute()

    socket =
      socket
      |> assign(:page_title, "Browse Programs")
      |> assign(:programs, programs)
      |> assign(:search_query, "")
      |> assign(:filters, %{})
      |> assign(:loading, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_params(socket, params)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:loading, true)
      |> assign(:search_query, query)

    programs =
      if query == "" do
        BrowsePrograms.execute(socket.assigns.filters)
      else
        BrowsePrograms.search(query, socket.assigns.filters)
      end

    socket =
      socket
      |> assign(:programs, programs)
      |> assign(:loading, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    programs = BrowsePrograms.execute(socket.assigns.filters)

    socket =
      socket
      |> assign(:programs, programs)
      |> assign(:search_query, "")

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = build_filters(params)

    programs =
      if socket.assigns.search_query == "" do
        BrowsePrograms.execute(filters)
      else
        BrowsePrograms.search(socket.assigns.search_query, filters)
      end

    socket =
      socket
      |> assign(:filters, filters)
      |> assign(:programs, programs)

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    programs =
      if socket.assigns.search_query == "" do
        BrowsePrograms.execute()
      else
        BrowsePrograms.search(socket.assigns.search_query)
      end

    socket =
      socket
      |> assign(:filters, %{})
      |> assign(:programs, programs)

    {:noreply, socket}
  end

  # Private helpers

  defp apply_params(socket, params) do
    filters = build_filters(params)
    search_query = Map.get(params, "q", "")

    programs =
      if search_query == "" do
        BrowsePrograms.execute(filters)
      else
        BrowsePrograms.search(search_query, filters)
      end

    socket
    |> assign(:filters, filters)
    |> assign(:search_query, search_query)
    |> assign(:programs, programs)
  end

  defp build_filters(params) do
    params
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      case parse_filter(key, value) do
        nil -> acc
        {filter_key, filter_value} -> Map.put(acc, filter_key, filter_value)
      end
    end)
  end

  defp parse_filter("category", value) when value != "", do: {:category, value}
  defp parse_filter("age_min", value) when value != "" do
    case Integer.parse(value) do
      {int, _} -> {:age_min, int}
      :error -> nil
    end
  end
  defp parse_filter("age_max", value) when value != "" do
    case Integer.parse(value) do
      {int, _} -> {:age_max, int}
      :error -> nil
    end
  end
  defp parse_filter("city", value) when value != "", do: {:city, value}
  defp parse_filter("state", value) when value != "", do: {:state, value}
  defp parse_filter("price_min", value) when value != "" do
    case Integer.parse(value) do
      {int, _} -> {:price_min, int}
      :error -> nil
    end
  end
  defp parse_filter("price_max", value) when value != "" do
    case Integer.parse(value) do
      {int, _} -> {:price_max, int}
      :error -> nil
    end
  end
  defp parse_filter("featured", "true"), do: {:featured, true}
  defp parse_filter("is_prime_youth", "true"), do: {:is_prime_youth, true}
  defp parse_filter(_key, _value), do: nil
end
