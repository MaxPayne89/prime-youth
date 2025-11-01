defmodule PrimeYouthWeb.ProgramsLive do
  use PrimeYouthWeb, :live_view

  import PrimeYouthWeb.Live.SampleFixtures
  import PrimeYouthWeb.ProgramComponents

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Programs")
      |> assign(current_user: nil)
      |> assign(search_query: "")
      |> assign(active_filter: "all")
      |> assign(programs: sample_programs())
      |> assign(filters: filter_options())

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_auth", _params, socket) do
    new_user = if !socket.assigns.current_user, do: sample_user()
    {:noreply, assign(socket, current_user: new_user)}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    {:noreply, assign(socket, search_query: query)}
  end

  @impl true
  def handle_event("filter_select", %{"filter" => filter_id}, socket) do
    {:noreply, assign(socket, active_filter: filter_id)}
  end

  @impl true
  def handle_event("toggle_favorite", %{"program" => _program_title}, socket) do
    # TODO: Implement favorite toggle functionality
    {:noreply, socket}
  end

  @impl true
  def handle_event("program_click", %{"program" => program_title}, socket) do
    # Find program by title and navigate to detail page
    program = Enum.find(socket.assigns.programs, fn p -> p.title == program_title end)

    if program do
      {:noreply, push_navigate(socket, to: ~p"/programs/#{program.id}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 pb-20 md:pb-6">
      <!-- Header -->
      <div class="bg-white p-6 shadow-sm">
        <div class="flex items-center justify-between mb-4">
          <h1 class="text-2xl font-bold text-gray-900">Programs</h1>
          <.icon_button
            icon_path="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"
            variant="light"
            class="text-gray-600"
            aria_label="More options"
          />
        </div>
        
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
      </div>
      
    <!-- Programs List -->
      <div class="p-6">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <.program_card
            :for={program <- filtered_programs(@programs, @search_query, @active_filter)}
            program={program}
            variant={:detailed}
            phx-click="program_click"
            phx-value-program={program.title}
          />
        </div>
        
    <!-- Empty State -->
        <.empty_state
          :if={Enum.empty?(filtered_programs(@programs, @search_query, @active_filter))}
          icon_path="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
          title="No programs found"
          description="Try adjusting your search or filter criteria."
        />
      </div>
    </div>
    """
  end

  # Helper functions
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
end
