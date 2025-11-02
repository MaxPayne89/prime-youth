defmodule PrimeYouthWeb.AboutLive do
  use PrimeYouthWeb, :live_view

  import PrimeYouthWeb.Live.SampleFixtures, except: [core_values: 0, key_features: 0, stats: 0]

  alias PrimeYouthWeb.UIComponents

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "About Us")
      |> assign(current_user: nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_auth", _params, socket) do
    new_user = if !socket.assigns.current_user, do: sample_user()
    {:noreply, assign(socket, current_user: new_user)}
  end

  # Private helpers - Sample data (local variations from fixtures)
  defp core_values do
    [
      %{
        icon: "hero-star",
        gradient: "bg-gradient-to-br from-prime-yellow-400 to-orange-500",
        title: "Quality First",
        description:
          "We partner with qualified instructors who are passionate about youth development"
      },
      %{
        icon: "hero-users",
        gradient: "bg-gradient-to-br from-prime-cyan-400 to-blue-500",
        title: "Accessibility",
        description:
          "Making enriching programs accessible to families through transparent pricing and easy booking"
      },
      %{
        icon: "hero-shield-check",
        gradient: "bg-gradient-to-br from-green-400 to-emerald-600",
        title: "Safety",
        description: "Verified instructors, secure facilities, and comprehensive safety protocols"
      },
      %{
        icon: "hero-heart",
        gradient: "bg-gradient-to-br from-prime-magenta-400 to-pink-500",
        title: "Community",
        description: "Building a supportive community of parents, instructors, and young learners"
      }
    ]
  end

  defp key_features do
    [
      %{
        icon: "hero-magnifying-glass",
        gradient: "bg-prime-cyan-100",
        title: "Easy Discovery",
        description: "Browse and filter programs by age, interest, location, and schedule"
      },
      %{
        icon: "hero-calendar",
        gradient: "bg-prime-magenta-100",
        title: "Simple Booking",
        description: "Book activities in minutes with clear pricing and flexible scheduling"
      },
      %{
        icon: "hero-credit-card",
        gradient: "bg-prime-yellow-100",
        title: "Secure Payments",
        description: "Safe, encrypted payment processing with multiple payment options"
      },
      %{
        icon: "hero-chart-bar",
        gradient: "bg-green-100",
        title: "Progress Tracking",
        description: "Monitor your child's participation and achievements in real-time"
      }
    ]
  end

  defp stats do
    [
      %{value: "500+", label: "Programs"},
      %{value: "1,200+", label: "Students"},
      %{value: "150+", label: "Instructors"},
      %{value: "98%", label: "Satisfaction"}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 pb-20 md:pb-6">
      <%!-- Hero Section --%>
      <.hero_section
        variant="page"
        gradient_class="bg-gradient-to-br from-prime-cyan-400 via-prime-magenta-400 to-prime-yellow-400"
        show_back_button
      >
        <:title>About Prime Youth</:title>
        <:subtitle>Empowering young minds through quality after-school programs</:subtitle>
      </.hero_section>

      <div class="max-w-4xl mx-auto p-6 space-y-8">
        <%!-- Mission Section --%>
        <.card>
          <:header>
            <h2 class="text-2xl font-bold text-gray-900">Our Mission</h2>
          </:header>
          <:body>
            <p class="text-gray-600 leading-relaxed">
              At Prime Youth, we believe every child deserves access to enriching after-school activities that nurture their talents and interests. We partner with qualified instructors to provide a diverse range of programs in arts, sports, academics, and technology.
            </p>
            <p class="text-gray-600 leading-relaxed mt-4">
              Our platform makes it easy for parents to discover, book, and manage activities while providing instructors with the tools they need to run successful programs.
            </p>
          </:body>
        </.card>

        <%!-- Core Values --%>
        <.card>
          <:header>
            <h2 class="text-2xl font-bold text-gray-900">Our Values</h2>
          </:header>
          <:body>
            <div class="space-y-4">
              <div :for={value <- core_values()} class="flex items-start gap-3">
                <div class="flex-shrink-0 mt-1">
                  <UIComponents.gradient_icon gradient_class={value.gradient} size="sm" shape="circle">
                    <.icon name={value.icon} class="w-5 h-5 text-white" />
                  </UIComponents.gradient_icon>
                </div>
                <div class="flex-1">
                  <h3 class="font-semibold text-gray-900 mb-1">{value.title}</h3>
                  <p class="text-sm text-gray-600">{value.description}</p>
                </div>
              </div>
            </div>
          </:body>
        </.card>

        <%!-- Key Features --%>
        <.card>
          <:header>
            <h2 class="text-2xl font-bold text-gray-900">Why Choose Prime Youth?</h2>
          </:header>
          <:body>
            <div class="grid md:grid-cols-2 gap-4">
              <div :for={feature <- key_features()} class="p-4 text-center">
                <div class={[
                  "w-16 h-16 mx-auto mb-4 rounded-full flex items-center justify-center",
                  feature.gradient
                ]}>
                  <.icon name={feature.icon} class="w-8 h-8 text-white" />
                </div>
                <h3 class="font-semibold text-gray-900 mb-2">{feature.title}</h3>
                <p class="text-sm text-gray-600">{feature.description}</p>
              </div>
            </div>
          </:body>
        </.card>

        <%!-- Stats Section --%>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <UIComponents.stat_display
            :for={stat <- stats()}
            value={stat.value}
            label={stat.label}
            gradient_class="bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400"
          />
        </div>

        <%!-- CTA Section --%>
        <.card padding="p-8">
          <:body>
            <div class="text-center">
              <h2 class="text-2xl font-bold text-gray-900 mb-3">Ready to Get Started?</h2>
              <p class="text-gray-600 mb-6">
                Explore our programs and find the perfect activities for your child.
              </p>
              <.link
                navigate={~p"/programs"}
                class="inline-block bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 text-white px-8 py-3 rounded-xl font-semibold hover:shadow-lg transform hover:scale-[1.02] transition-all"
              >
                Browse Programs
              </.link>
            </div>
          </:body>
        </.card>
      </div>
    </div>
    """
  end
end
