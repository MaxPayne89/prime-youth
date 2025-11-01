defmodule PrimeYouthWeb.HomeLive do
  use PrimeYouthWeb, :live_view

  import PrimeYouthWeb.Live.SampleFixtures
  import PrimeYouthWeb.UIComponents

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
    new_user = if !socket.assigns.current_user, do: sample_user()
    {:noreply, assign(socket, current_user: new_user)}
  end

  @impl true
  def handle_event("explore_programs", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/programs")}
  end

  @impl true
  def handle_event("get_started", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/users/register")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <!-- Hero Section -->
      <.hero_section
        variant="landing"
        gradient_class="bg-gradient-to-br from-prime-cyan-400 via-prime-magenta-400 to-prime-yellow-400"
        show_logo
      >
        <:title>Prime Youth</:title>
        <:subtitle>Afterschool Adventures Await</:subtitle>
        <:actions>
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
        </:actions>
      </.hero_section>
      
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
            <.feature_card
              gradient_class="bg-gradient-to-br from-prime-cyan-400 to-blue-500"
              icon_path="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
              title="Expert Instructors & Small Class Sizes"
              description="All instructors are background-checked and classes are limited to ensure personalized attention"
            />
            <.feature_card
              gradient_class="bg-gradient-to-br from-prime-magenta-400 to-pink-500"
              icon_path="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
              title="Comprehensive Progress Tracking"
              description="Monitor your child's development with regular updates, achievements, and progress reports"
            />
            <.feature_card
              gradient_class="bg-gradient-to-br from-prime-yellow-400 to-orange-500"
              icon_path="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
              title="Flexible Scheduling & Pricing"
              description="Find programs that fit your family's schedule with transparent pricing and easy online booking"
            />
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
            <.program_card_simple
              :for={program <- @featured_programs}
              gradient_class={program.gradient_class}
              icon_path={program.icon_path}
              title={program.title}
              description={program.description}
              price={program.price}
              phx-click="explore_programs"
            />
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

          <div class="grid md:grid-cols-3 gap-8">
            <.stat_display
              value="10,000+"
              label="Active Families"
              gradient_class="bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400"
            />
            <.stat_display
              value="500+"
              label="Programs Available"
              gradient_class="bg-gradient-to-r from-prime-magenta-400 to-prime-yellow-400"
            />
            <.stat_display
              value="4.9/5"
              label="Average Rating"
              gradient_class="bg-gradient-to-r from-prime-yellow-400 to-prime-cyan-400"
            />
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
end
