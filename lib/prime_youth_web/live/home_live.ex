defmodule PrimeYouthWeb.HomeLive do
  use PrimeYouthWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Prime Youth - Afterschool Adventures Await")
      |> assign(current_user: nil)
      |> assign(featured_programs: featured_programs())

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_auth", _params, socket) do
    new_user = if socket.assigns.current_user, do: nil, else: sample_user()
    {:noreply, assign(socket, current_user: new_user)}
  end

  @impl true
  def handle_event("explore_programs", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/programs")}
  end

  @impl true
  def handle_event("get_started", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/signup")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <!-- Hero Section -->
      <div class="relative overflow-hidden bg-gradient-to-br from-prime-cyan-400 via-prime-magenta-400 to-prime-yellow-400">
        <div class="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-24 lg:py-32">
          <div class="text-center">
            <!-- Logo -->
            <div class="inline-flex items-center justify-center w-24 h-24 bg-white rounded-full shadow-lg mb-8 animate-bounce-gentle">
              <img src={~p"/images/logo-standard.png"} alt="Prime Youth Logo" class="w-16 h-16 object-contain" />
            </div>
            <h1 class="text-5xl md:text-6xl lg:text-7xl font-bold text-white mb-4 animate-fade-in">
              Prime Youth
            </h1>
            <p class="text-2xl md:text-3xl text-white/90 mb-8 max-w-3xl mx-auto">
              Afterschool Adventures Await
            </p>
            <div class="flex flex-col sm:flex-row gap-4 justify-center">
              <button
                phx-click="get_started"
                class="px-8 py-4 bg-white text-gray-900 rounded-xl font-semibold text-lg hover:bg-gray-100 transform hover:scale-105 transition-all duration-200 shadow-lg"
              >
                Get Started Free
              </button>
              <button
                phx-click="explore_programs"
                class="px-8 py-4 bg-white/20 backdrop-blur-sm border-2 border-white text-white rounded-xl font-semibold text-lg hover:bg-white/30 transition-all duration-200"
              >
                Explore Programs
              </button>
            </div>
          </div>
        </div>

        <!-- Decorative Wave -->
        <div class="absolute bottom-0 left-0 right-0">
          <svg class="w-full h-16 fill-white" viewBox="0 0 1200 120" preserveAspectRatio="none">
            <path d="M321.39,56.44c58-10.79,114.16-30.13,172-41.86,82.39-16.72,168.19-17.73,250.45-.39C823.78,31,906.67,72,985.66,92.83c70.05,18.48,146.53,26.09,214.34,3V0H0V27.35A600.21,600.21,0,0,0,321.39,56.44Z">
            </path>
          </svg>
        </div>
      </div>

      <!-- Features Section -->
      <div class="bg-white">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 lg:py-24">
          <div class="text-center mb-16">
            <h2 class="text-3xl md:text-4xl font-bold text-gray-900 mb-4">
              Why Families Choose Prime Youth
            </h2>
            <p class="text-xl text-gray-600">
              Expert instructors, comprehensive tracking, and flexible scheduling for your family
            </p>
          </div>

        <div class="grid md:grid-cols-3 gap-8 lg:gap-12">
          <!-- Feature 1 -->
          <div class="text-center group hover:transform hover:scale-105 transition-all duration-200">
            <div class="w-16 h-16 bg-gradient-to-br from-prime-cyan-400 to-blue-500 rounded-2xl flex items-center justify-center mx-auto mb-6 group-hover:shadow-lg transition-shadow">
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
                  d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
                >
                </path>
              </svg>
            </div>
            <h3 class="text-xl font-semibold text-gray-900 mb-3">Expert Instructors & Small Class Sizes</h3>
            <p class="text-gray-600">
              All instructors are background-checked and classes are limited to ensure personalized attention
            </p>
          </div>

          <!-- Feature 2 -->
          <div class="text-center group hover:transform hover:scale-105 transition-all duration-200">
            <div class="w-16 h-16 bg-gradient-to-br from-prime-magenta-400 to-pink-500 rounded-2xl flex items-center justify-center mx-auto mb-6 group-hover:shadow-lg transition-shadow">
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
                  d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
                >
                </path>
              </svg>
            </div>
            <h3 class="text-xl font-semibold text-gray-900 mb-3">Comprehensive Progress Tracking</h3>
            <p class="text-gray-600">
              Monitor your child's development with regular updates, achievements, and progress reports
            </p>
          </div>

          <!-- Feature 3 -->
          <div class="text-center group hover:transform hover:scale-105 transition-all duration-200">
            <div class="w-16 h-16 bg-gradient-to-br from-prime-yellow-400 to-orange-500 rounded-2xl flex items-center justify-center mx-auto mb-6 group-hover:shadow-lg transition-shadow">
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
                  d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                >
                </path>
              </svg>
            </div>
            <h3 class="text-xl font-semibold text-gray-900 mb-3">Flexible Scheduling & Pricing</h3>
            <p class="text-gray-600">
              Find programs that fit your family's schedule with transparent pricing and easy online booking
            </p>
          </div>
        </div>
        </div>
      </div>

      <!-- Featured Programs Section -->
      <div class="bg-gray-50 py-16 lg:py-24">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-12">
            <h2 class="text-3xl md:text-4xl font-bold text-gray-900 mb-4">
              Popular Programs
            </h2>
            <p class="text-xl text-gray-600">
              Discover what families are enrolling in this season
            </p>
          </div>

          <div class="grid md:grid-cols-3 gap-6 lg:gap-8 mb-8">
            <div
              :for={program <- @featured_programs}
              class="bg-white rounded-2xl shadow-sm border border-gray-100 hover:shadow-lg transition-all duration-300 overflow-hidden group cursor-pointer"
              phx-click="explore_programs"
            >
              <div class={["h-48 relative", program.gradient_class]}>
                <div class="absolute inset-0 bg-black/10 group-hover:bg-black/5 transition-colors">
                </div>
                <div class="absolute inset-0 flex items-center justify-center">
                  <div class="w-20 h-20 bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center">
                    <svg
                      class="w-10 h-10 text-white"
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
              <div class="p-6">
                <h3 class="text-xl font-bold text-gray-900 mb-2">{program.title}</h3>
                <p class="text-gray-600 text-sm mb-4 line-clamp-2">{program.description}</p>
                <div class="flex items-center justify-between">
                  <span class="text-2xl font-bold text-prime-magenta-400">€{program.price}</span>
                  <span class="text-sm text-gray-500">per week</span>
                </div>
              </div>
            </div>
          </div>

          <div class="text-center">
            <button
              phx-click="explore_programs"
              class="px-8 py-3 bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 text-white rounded-xl font-semibold hover:shadow-lg transform hover:scale-105 transition-all duration-200"
            >
              View All Programs →
            </button>
          </div>
        </div>
      </div>

      <!-- Social Proof / Trust Section -->
      <div class="bg-white">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 lg:py-24">
          <div class="text-center mb-12">
            <h2 class="text-3xl md:text-4xl font-bold text-gray-900 mb-4">
              Trusted by Families Everywhere
            </h2>
          </div>

          <div class="grid md:grid-cols-3 gap-8 text-center">
            <div>
              <div class="text-4xl md:text-5xl font-bold bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 bg-clip-text text-transparent mb-2">10,000+</div>
              <div class="text-gray-600">Active Families</div>
            </div>
            <div>
              <div class="text-4xl md:text-5xl font-bold bg-gradient-to-r from-prime-magenta-400 to-prime-yellow-400 bg-clip-text text-transparent mb-2">500+</div>
              <div class="text-gray-600">Programs Available</div>
            </div>
            <div>
              <div class="text-4xl md:text-5xl font-bold bg-gradient-to-r from-prime-yellow-400 to-prime-cyan-400 bg-clip-text text-transparent mb-2">4.9/5</div>
              <div class="text-gray-600">Average Rating</div>
            </div>
          </div>
        </div>
      </div>

      <!-- CTA Section -->
      <div class="bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 py-16 lg:py-20">
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 class="text-3xl md:text-4xl font-bold text-white mb-6">
            Ready to Get Started?
          </h2>
          <p class="text-xl text-white/90 mb-8">
            Join thousands of families discovering amazing afterschool programs
          </p>
          <button
            phx-click="get_started"
            class="px-8 py-4 bg-white text-prime-cyan-400 rounded-xl font-semibold text-lg hover:bg-gray-100 transform hover:scale-105 transition-all duration-200 shadow-lg"
          >
            Create Free Account →
          </button>
        </div>
      </div>
    </div>
    """
  end

  # Sample data
  defp sample_user do
    %{
      name: "Sarah Johnson",
      email: "sarah.johnson@example.com",
      avatar:
        "https://images.unsplash.com/photo-1494790108755-2616b612b388?w=64&h=64&fit=crop&crop=face"
    }
  end

  defp featured_programs do
    [
      %{
        id: 1,
        title: "Creative Art World",
        description:
          "Unleash your child's creativity through painting, drawing, and sculpture",
        gradient_class: "bg-gradient-to-br from-yellow-400 via-orange-500 to-yellow-600",
        icon_path:
          "M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v1.5L15 4l2 7-7 2.5V15a2 2 0 01-2 2z",
        price: 45
      },
      %{
        id: 2,
        title: "Chess Masters",
        description: "Learn strategic thinking and problem-solving through chess",
        gradient_class: "bg-gradient-to-br from-gray-700 via-gray-800 to-black",
        icon_path:
          "M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z",
        price: 35
      },
      %{
        id: 3,
        title: "Soccer Skills",
        description: "Develop soccer fundamentals in a fun, supportive environment",
        gradient_class: "bg-gradient-to-br from-green-500 via-emerald-600 to-teal-700",
        icon_path:
          "M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z",
        price: 40
      }
    ]
  end
end
