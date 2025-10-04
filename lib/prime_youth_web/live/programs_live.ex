defmodule PrimeYouthWeb.ProgramsLive do
  use PrimeYouthWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Programs")
      |> assign(search_query: "")
      |> assign(active_filter: "all")
      |> assign(programs: sample_programs())
      |> assign(filters: filter_options())

    {:ok, socket}
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
          <button class="p-2 bg-gray-100 rounded-full hover:bg-gray-200 transition-colors">
            <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"
              >
              </path>
            </svg>
          </button>
        </div>
        
    <!-- Search Bar -->
        <div class="relative mb-4">
          <input
            type="text"
            placeholder="Search programs..."
            value={@search_query}
            phx-change="search"
            name="search"
            class="w-full pl-10 pr-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-prime-cyan-400/50 focus:border-prime-cyan-400 transition-all"
          />
          <svg
            class="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
            >
            </path>
          </svg>
        </div>
        
    <!-- Filter Pills -->
        <div class="flex gap-2 overflow-x-auto pb-2">
          <button
            :for={filter <- @filters}
            phx-click="filter_select"
            phx-value-filter={filter.id}
            class={[
              "px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-all",
              if(@active_filter == filter.id,
                do: "bg-prime-cyan-400 text-white",
                else: "bg-gray-100 text-gray-700 hover:bg-gray-200"
              )
            ]}
          >
            {filter.label}
          </button>
        </div>
      </div>
      
    <!-- Programs List -->
      <div class="p-6">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <div
            :for={program <- filtered_programs(@programs, @search_query, @active_filter)}
            class="bg-white rounded-2xl shadow-sm border border-gray-100 hover:shadow-md transition-all duration-300 overflow-hidden"
          >
            <!-- Program Image/Header -->
            <div class={["h-48 relative overflow-hidden", program.gradient_class]}>
              <div class="absolute inset-0 bg-black/10"></div>
              <div class="absolute top-4 right-4 z-10">
                <button
                  phx-click="toggle_favorite"
                  phx-value-program={program.title}
                  class="p-2 bg-white/80 backdrop-blur-sm rounded-full hover:bg-white transition-colors"
                >
                  <svg
                    class="w-5 h-5 text-gray-600 hover:text-red-500"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"
                    />
                  </svg>
                </button>
              </div>
              
    <!-- Spots Left Badge -->
              <div :if={program.spots_left <= 5} class="absolute bottom-4 left-4">
                <span class={[
                  "px-2 py-1 rounded-full text-xs font-medium",
                  if(program.spots_left <= 2,
                    do: "bg-red-100 text-red-700",
                    else: "bg-orange-100 text-orange-700"
                  )
                ]}>
                  {program.spots_left} spots left!
                </span>
              </div>
              
    <!-- Program Icon -->
              <div class="absolute inset-0 flex items-center justify-center">
                <div class="w-16 h-16 bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center">
                  <svg
                    class="w-8 h-8 text-white"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d={program.icon_path}
                    >
                    </path>
                  </svg>
                </div>
              </div>
            </div>
            
    <!-- Program Info -->
            <div class="p-6">
              <div class="flex items-start justify-between mb-3">
                <div class="flex-1">
                  <h3 class="font-bold text-gray-900 text-lg mb-2">{program.title}</h3>
                  <p class="text-gray-600 text-sm mb-3 line-clamp-2">{program.description}</p>
                </div>
              </div>
              
    <!-- Program Details -->
              <div class="space-y-2 mb-4">
                <div class="flex items-center text-sm text-gray-600">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                    >
                    </path>
                  </svg>
                  {program.schedule}
                </div>
                <div class="flex items-center text-sm text-gray-600">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
                    >
                    </path>
                  </svg>
                  Ages {program.age_range}
                </div>
              </div>
              
    <!-- Price and CTA -->
              <div class="flex items-center justify-between pt-4 border-t border-gray-100">
                <div>
                  <div class="text-lg font-bold text-prime-cyan-400">
                    {format_price(program.price)}
                  </div>
                  <div class="text-sm text-gray-500">{program.period}</div>
                </div>
                <button
                  phx-click="program_click"
                  phx-value-program={program.title}
                  class="px-4 py-2 bg-prime-cyan-400 text-white rounded-lg hover:bg-prime-cyan-500 transition-colors font-medium"
                >
                  Learn More
                </button>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Empty State -->
        <div
          :if={Enum.empty?(filtered_programs(@programs, @search_query, @active_filter))}
          class="text-center py-12"
        >
          <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
              >
              </path>
            </svg>
          </div>
          <h3 class="text-lg font-semibold text-gray-900 mb-2">No programs found</h3>
          <p class="text-gray-600">Try adjusting your search or filter criteria.</p>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
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

  defp format_price(0), do: "Free"
  defp format_price(amount) when is_integer(amount), do: "$#{amount}"

  defp format_price(amount) when is_float(amount),
    do: "$#{:erlang.float_to_binary(amount, decimals: 2)}"
end
