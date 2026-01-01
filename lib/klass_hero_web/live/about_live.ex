defmodule KlassHeroWeb.AboutLive do
  use KlassHeroWeb, :live_view

  alias KlassHeroWeb.{Theme, UIComponents}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: gettext("About Us"))

    {:ok, socket}
  end

  # Private helpers - Sample data (local variations from fixtures)
  defp core_values do
    [
      %{
        icon: "hero-star",
        gradient: Theme.gradient(:primary),
        title: gettext("Quality First"),
        description:
          gettext(
            "We partner with qualified instructors who are passionate about youth development"
          )
      },
      %{
        icon: "hero-users",
        gradient: Theme.gradient(:primary),
        title: gettext("Accessibility"),
        description:
          gettext(
            "Making enriching programs accessible to families through transparent pricing and easy booking"
          )
      },
      %{
        icon: "hero-shield-check",
        gradient: Theme.gradient(:safety),
        title: gettext("Safety"),
        description:
          gettext("Verified instructors, secure facilities, and comprehensive safety protocols")
      },
      %{
        icon: "hero-heart",
        gradient: Theme.gradient(:primary),
        title: gettext("Community"),
        description:
          gettext("Building a supportive community of parents, instructors, and young learners")
      }
    ]
  end

  defp key_features do
    [
      %{
        icon: "hero-magnifying-glass",
        gradient: Theme.bg(:primary_light),
        title: gettext("Easy Discovery"),
        description:
          gettext("Browse and filter programs by age, interest, location, and schedule")
      },
      %{
        icon: "hero-calendar",
        gradient: Theme.bg(:secondary_light),
        title: gettext("Simple Booking"),
        description:
          gettext("Book activities in minutes with clear pricing and flexible scheduling")
      },
      %{
        icon: "hero-credit-card",
        gradient: Theme.bg(:accent_light),
        title: gettext("Secure Payments"),
        description: gettext("Safe, encrypted payment processing with multiple payment options")
      },
      %{
        icon: "hero-chart-bar",
        gradient: Theme.bg(:primary_light),
        title: gettext("Progress Tracking"),
        description: gettext("Monitor your child's participation and achievements in real-time")
      }
    ]
  end

  defp stats do
    [
      %{value: "500+", label: gettext("Programs")},
      %{value: "1,200+", label: gettext("Students")},
      %{value: "150+", label: gettext("Instructors")},
      %{value: "98%", label: gettext("Satisfaction")}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen pb-20 md:pb-6", Theme.bg(:muted)]}>
      <%!-- Hero Section --%>
      <.hero_section
        variant="page"
        gradient_class={Theme.gradient(:hero)}
        show_back_button
      >
        <:title>{gettext("About Klass Hero Connect")}</:title>
        <:subtitle>
          {gettext("Empowering young minds through quality after-school programs")}
        </:subtitle>
      </.hero_section>

      <div class="max-w-4xl mx-auto p-6 space-y-8">
        <%!-- Mission Section --%>
        <.card>
          <:header>
            <h2 class={[Theme.typography(:section_title), Theme.text_color(:heading)]}>
              {gettext("Our Mission")}
            </h2>
          </:header>
          <:body>
            <p class={[Theme.text_color(:secondary), "leading-relaxed"]}>
              {gettext(
                "At Klass Hero Connect, we believe every child deserves access to enriching after-school activities that nurture their talents and interests. We partner with qualified instructors to provide a diverse range of programs in arts, sports, academics, and technology."
              )}
            </p>
            <p class={[Theme.text_color(:secondary), "leading-relaxed mt-4"]}>
              {gettext(
                "Our platform makes it easy for parents to discover, book, and manage activities while providing instructors with the tools they need to run successful programs."
              )}
            </p>
          </:body>
        </.card>

        <%!-- Core Values --%>
        <.card>
          <:header>
            <h2 class={[Theme.typography(:section_title), Theme.text_color(:heading)]}>
              {gettext("Our Values")}
            </h2>
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
                  <h3 class={["font-semibold mb-1", Theme.text_color(:heading)]}>{value.title}</h3>
                  <p class={["text-sm", Theme.text_color(:secondary)]}>{value.description}</p>
                </div>
              </div>
            </div>
          </:body>
        </.card>

        <%!-- Key Features --%>
        <.card>
          <:header>
            <h2 class={[Theme.typography(:section_title), Theme.text_color(:heading)]}>
              {gettext("Why Choose Klass Hero Connect?")}
            </h2>
          </:header>
          <:body>
            <div class="grid md:grid-cols-2 gap-4">
              <div :for={feature <- key_features()} class="p-4 text-center">
                <div class={[
                  "w-16 h-16 mx-auto mb-4 flex items-center justify-center",
                  Theme.rounded(:full),
                  feature.gradient
                ]}>
                  <.icon name={feature.icon} class="w-8 h-8 text-white" />
                </div>
                <h3 class={["font-semibold mb-2", Theme.text_color(:heading)]}>{feature.title}</h3>
                <p class={["text-sm", Theme.text_color(:secondary)]}>{feature.description}</p>
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
            gradient_class={Theme.gradient(:primary)}
          />
        </div>

        <%!-- CTA Section --%>
        <.card padding="p-8">
          <:body>
            <div class="text-center">
              <h2 class={[Theme.typography(:section_title), "mb-3", Theme.text_color(:heading)]}>
                {gettext("Ready to Get Started?")}
              </h2>
              <p class={["mb-6", Theme.text_color(:secondary)]}>
                {gettext("Explore our programs and find the perfect activities for your child.")}
              </p>
              <.link
                navigate={~p"/programs"}
                class={[
                  "inline-block",
                  Theme.gradient(:primary),
                  "text-white px-8 py-3 font-semibold hover:shadow-lg transform hover:scale-[1.02]",
                  Theme.transition(:normal),
                  Theme.rounded(:lg)
                ]}
              >
                {gettext("Browse Programs")}
              </.link>
            </div>
          </:body>
        </.card>
      </div>
    </div>
    """
  end
end
