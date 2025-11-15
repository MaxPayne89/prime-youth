defmodule PrimeYouthWeb.ProgramsLive do
  use PrimeYouthWeb, :live_view

  import PrimeYouthWeb.ProgramComponents

  alias PrimeYouth.ProgramCatalog.Application.UseCases.ListAllPrograms

  if Mix.env() == :dev do
    use PrimeYouthWeb.DevAuthToggle
  end

  @valid_filters ["all", "available", "ages", "price"]

  # Private helpers - Static data
  defp filter_options do
    [
      %{id: "all", label: "All Programs"},
      %{id: "available", label: "Available"},
      %{id: "ages", label: "By Age"},
      %{id: "price", label: "By Price"}
    ]
  end

  @impl true
  def mount(_params, _session, socket) do
    # Load programs from database using the use case
    case ListAllPrograms.execute() do
      {:ok, domain_programs} ->
        programs = Enum.map(domain_programs, &program_to_map/1)

        socket =
          socket
          |> assign(page_title: "Programs")
          |> assign(current_user: nil)
          |> stream(:programs, programs)
          |> assign(programs_count: length(programs))
          |> assign(filters: filter_options())
          |> assign(database_error: false)

        {:ok, socket}

      {:error, :database_error} ->
        socket =
          socket
          |> assign(page_title: "Programs")
          |> assign(current_user: nil)
          |> stream(:programs, [])
          |> assign(programs_count: 0)
          |> assign(filters: filter_options())
          |> assign(database_error: true)
          |> put_flash(:error, "Unable to load programs. Please try again later.")

        {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    search_query = sanitize_search_query(params["q"])
    active_filter = validate_filter(params["filter"])

    # Re-fetch and filter programs based on params
    case ListAllPrograms.execute() do
      {:ok, domain_programs} ->
        programs = Enum.map(domain_programs, &program_to_map/1)
        filtered = filtered_programs(programs, search_query, active_filter)

        socket =
          socket
          |> assign(search_query: search_query)
          |> assign(active_filter: active_filter)
          |> stream(:programs, filtered, reset: true)
          |> assign(:programs_empty?, Enum.empty?(filtered))
          |> assign(database_error: false)

        {:noreply, socket}

      {:error, :database_error} ->
        socket =
          socket
          |> assign(search_query: search_query)
          |> assign(active_filter: active_filter)
          |> stream(:programs, [], reset: true)
          |> assign(:programs_empty?, true)
          |> assign(database_error: true)
          |> put_flash(:error, "Unable to load programs. Please try again later.")

        {:noreply, socket}
    end
  end

  # Private helper - Domain to UI conversion
  defp program_to_map(%PrimeYouth.ProgramCatalog.Domain.Models.Program{} = program) do
    %{
      id: program.id,
      title: program.title,
      description: program.description,
      schedule: program.schedule,
      age_range: program.age_range,
      price: Decimal.to_float(program.price),
      period: program.pricing_period,
      spots_left: program.spots_available,
      # Default UI properties (these will come from the database in the future)
      gradient_class: program.gradient_class || default_gradient_class(),
      icon_path: program.icon_path || default_icon_path()
    }
  end

  defp default_gradient_class, do: "bg-gradient-to-br from-blue-500 via-purple-500 to-pink-500"

  defp default_icon_path,
    do: "M12 14l9-5-9-5-9 5 9 5zm0 7l-9-5 9-5 9 5-9 5zM3 12l9-5 9 5-9 5-9-5z"

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    params = build_query_params(socket.assigns, q: query)
    {:noreply, push_patch(socket, to: ~p"/programs?#{params}")}
  end

  @impl true
  def handle_event("filter_select", %{"filter" => filter_id}, socket) do
    params = build_query_params(socket.assigns, filter: filter_id)
    {:noreply, push_patch(socket, to: ~p"/programs?#{params}")}
  end

  @impl true
  def handle_event("toggle_favorite", %{"program" => _program_title}, socket) do
    # TODO: Implement favorite toggle functionality
    {:noreply, socket}
  end

  @impl true
  def handle_event("program_click", %{"program" => program_title}, socket) do
    # Find program by title from database and navigate to detail page
    case ListAllPrograms.execute() do
      {:ok, domain_programs} ->
        programs = Enum.map(domain_programs, &program_to_map/1)

        case Enum.find(programs, fn p -> p.title == program_title end) do
          nil ->
            {:noreply,
             socket
             |> put_flash(:error, "Program not found. Please try refreshing the page.")
             |> push_patch(to: ~p"/programs")}

          program ->
            {:noreply, push_navigate(socket, to: ~p"/programs/#{program.id}")}
        end

      {:error, :database_error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Unable to load program details. Please try again later.")
         |> push_patch(to: ~p"/programs")}
    end
  end

  # Private helpers - URL and parameter handling
  defp build_query_params(assigns, updates) do
    # Convert keyword list updates to string-keyed map
    updates_map =
      updates
      |> Map.new(fn {k, v} -> {to_string(k), v} end)

    %{
      "q" => assigns.search_query,
      "filter" => assigns.active_filter
    }
    |> Map.merge(updates_map)
    |> Enum.reject(fn {_k, v} -> v == "" || v == "all" end)
    |> Map.new()
  end

  defp validate_filter(nil), do: "all"
  defp validate_filter(filter) when filter in @valid_filters, do: filter
  defp validate_filter(_invalid), do: "all"

  defp sanitize_search_query(nil), do: ""

  defp sanitize_search_query(query) do
    query
    |> String.trim()
    |> String.slice(0, 100)
  end

  # Private helpers - Business logic
  defp filtered_programs(programs, search_query, filter) do
    programs
    |> filter_by_search(search_query)
    |> filter_by_category(filter)
  end

  defp filter_by_search(programs, ""), do: programs

  defp filter_by_search(programs, query) do
    query_lower = String.downcase(query)

    Enum.filter(programs, fn program ->
      String.contains?(String.downcase(program.title), query_lower) ||
        String.contains?(String.downcase(program.description), query_lower)
    end)
  end

  defp filter_by_category(programs, "all"), do: programs

  defp filter_by_category(programs, "available") do
    Enum.filter(programs, &(&1.spots_left > 0))
  end

  defp filter_by_category(programs, "ages") do
    # Sort by age range (youngest first)
    Enum.sort_by(programs, &extract_min_age(&1.age_range))
  end

  defp filter_by_category(programs, "price") do
    # Sort by price (lowest first)
    Enum.sort_by(programs, & &1.price)
  end

  defp extract_min_age(age_range) do
    age_range
    |> String.split("-")
    |> List.first()
    |> String.to_integer()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 pb-20 md:pb-6">
      <!-- Header -->
      <.page_header>
        <:title>Programs</:title>
        <:actions>
          <.icon_button
            icon_path="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"
            variant="light"
            class="text-gray-600"
            aria_label="More options"
          />
        </:actions>
      </.page_header>

      <div class="p-6">
        <!-- Search Bar -->
        <.search_bar
          placeholder="Search programs..."
          value={@search_query}
          name="search"
          phx-change="search"
          class="mb-4"
        />
        
    <!-- Filter Pills -->
        <.filter_pills
          filters={@filters}
          active_filter={@active_filter}
          phx-click="filter_select"
        />
        
    <!-- Programs List -->
        <div
          id="programs"
          phx-update="stream"
          class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
        >
          <.program_card
            :for={{dom_id, program} <- @streams.programs}
            id={dom_id}
            program={program}
            variant={:detailed}
            phx-click="program_click"
            phx-value-program={program.title}
          />
        </div>
        
    <!-- Empty State -->
        <.empty_state
          :if={@programs_empty?}
          icon_path="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
          title="No programs found"
          description="Try adjusting your search or filter criteria."
        />
      </div>
    </div>
    """
  end
end
