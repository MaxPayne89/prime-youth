defmodule PrimeYouthWeb.ProgramsLive do
  use PrimeYouthWeb, :live_view
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
    new_user = if socket.assigns.current_user, do: nil, else: sample_user()
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
  defp sample_user do
    %{
      name: "Sarah Johnson",
      email: "sarah.johnson@example.com",
      avatar:
        "https://images.unsplash.com/photo-1494790108755-2616b612b388?w=64&h=64&fit=crop&crop=face"
    }
  end

  defp filter_options do
    [
      %{id: "all", label: "All Programs"},
      %{id: "available", label: "Available"},
      %{id: "ages", label: "By Age"},
      %{id: "price", label: "By Price"}
    ]
  end

  defp sample_programs do
    [
      %{
        id: 1,
        title: "Creative Art World",
        description:
          "Unleash your child's creativity through painting, drawing, sculpture, and mixed media projects. Each session explores different artistic techniques and mediums.",
        gradient_class: "bg-gradient-to-br from-orange-400 via-pink-500 to-purple-600",
        icon_path:
          "M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v1.5L15 4l2 7-7 2.5V15a2 2 0 01-2 2z",
        schedule: "Wednesdays 4-6 PM",
        age_range: "6-12",
        price: 30,
        period: "per session",
        spots_left: 2
      },
      %{
        id: 2,
        title: "Chess Masters",
        description:
          "Learn strategic thinking and problem-solving through the ancient game of chess. Perfect for developing critical thinking skills and patience.",
        gradient_class: "bg-gradient-to-br from-gray-700 via-gray-800 to-black",
        icon_path:
          "M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z",
        schedule: "Mon, Wed 4-5 PM",
        age_range: "8-14",
        price: 25,
        period: "per session",
        spots_left: 5
      },
      %{
        id: 3,
        title: "Science Explorers",
        description:
          "Hands-on science experiments and discovery. Making learning fun through interactive activities and real-world applications.",
        gradient_class: "bg-gradient-to-br from-green-400 via-blue-500 to-purple-600",
        icon_path:
          "M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z",
        schedule: "Fri 4-5:30 PM",
        age_range: "7-11",
        price: 35,
        period: "per session",
        spots_left: 8
      },
      %{
        id: 4,
        title: "Soccer Skills",
        description:
          "Develop fundamental soccer skills including dribbling, passing, shooting, and teamwork. All skill levels welcome in a fun, supportive environment.",
        gradient_class: "bg-gradient-to-br from-green-500 via-emerald-600 to-teal-700",
        icon_path:
          "M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z",
        schedule: "Saturdays 10-11:30 AM",
        age_range: "5-10",
        price: 20,
        period: "per session",
        spots_left: 12
      },
      %{
        id: 5,
        title: "Music & Movement",
        description:
          "Introduction to music through singing, dancing, and simple instruments. Builds rhythm, coordination, and musical appreciation.",
        gradient_class: "bg-gradient-to-br from-pink-400 via-purple-500 to-indigo-600",
        icon_path:
          "M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z M21 16c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z",
        schedule: "Tuesdays 3:30-4:30 PM",
        age_range: "3-6",
        price: 28,
        period: "per session",
        spots_left: 6
      },
      %{
        id: 6,
        title: "Coding for Kids",
        description:
          "Introduction to programming concepts through fun, visual coding languages and games. Build logic skills and creativity.",
        gradient_class: "bg-gradient-to-br from-blue-500 via-indigo-600 to-purple-700",
        icon_path: "M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4",
        schedule: "Thursdays 5-6 PM",
        age_range: "8-12",
        price: 40,
        period: "per session",
        spots_left: 4
      }
    ]
  end

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
