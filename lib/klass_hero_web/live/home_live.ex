defmodule KlassHeroWeb.HomeLive do
  use KlassHeroWeb, :live_view

  import KlassHeroWeb.UIComponents

  alias KlassHero.ProgramCatalog.Application.UseCases.ListFeaturedPrograms
  alias KlassHeroWeb.Theme

  @impl true
  def mount(_params, _session, socket) do
    featured = ListFeaturedPrograms.execute()

    socket =
      socket
      |> assign(
        page_title: gettext("Klass Hero - Connecting Families with Trusted Youth Educators")
      )
      |> stream(:featured_programs, featured)
      |> assign(:featured_empty?, Enum.empty?(featured))

    {:ok, socket}
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
        show_logo
      >
        <:title>
          <span class="text-hero-grey-600">Connecting Families with Trusted</span>
          <br />
          <span class="text-hero-black">Heroes for Our Youth</span>
        </:title>
        <:search_bar>
          <div class="max-w-3xl mx-auto mb-8">
            <div class="flex items-center gap-2 bg-white rounded-full shadow-sm p-2">
              <div class="flex-1 flex items-center px-4">
                <svg
                  class="w-5 h-5 text-hero-grey-400 mr-2"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                  />
                </svg>
                <input
                  type="text"
                  placeholder="Search for programs..."
                  class="w-full outline-none text-hero-black bg-transparent"
                  disabled
                />
              </div>
              <button class="bg-hero-blue-600 text-white px-6 py-3 rounded-full font-semibold hover:bg-hero-blue-700 transition-all duration-200">
                SEARCH
              </button>
            </div>
          </div>
        </:search_bar>
        <:trending_tags>
          <div class="flex flex-wrap justify-center gap-2 mb-8">
            <span class="text-sm text-hero-grey-600 font-medium mr-2">Trending:</span>
            <span class="px-4 py-2 bg-white/80 backdrop-blur-sm rounded-full text-sm text-hero-black border border-hero-grey-200 cursor-default">
              Swimming
            </span>
            <span class="px-4 py-2 bg-white/80 backdrop-blur-sm rounded-full text-sm text-hero-black border border-hero-grey-200 cursor-default">
              Math Tutor
            </span>
            <span class="px-4 py-2 bg-white/80 backdrop-blur-sm rounded-full text-sm text-hero-black border border-hero-grey-200 cursor-default">
              Summer Camp
            </span>
            <span class="px-4 py-2 bg-white/80 backdrop-blur-sm rounded-full text-sm text-hero-black border border-hero-grey-200 cursor-default">
              Piano
            </span>
            <span class="px-4 py-2 bg-white/80 backdrop-blur-sm rounded-full text-sm text-hero-black border border-hero-grey-200 cursor-default">
              Soccer
            </span>
          </div>
        </:trending_tags>
        <:actions>
          <button
            phx-click="get_started"
            class={[
              "px-8 py-4 transform hover:scale-105 shadow-lg",
              Theme.typography(:cta),
              Theme.transition(:normal),
              Theme.rounded(:lg),
              Theme.bg(:surface),
              Theme.text_color(:heading),
              "hover:#{Theme.bg(:light)}"
            ]}
          >
            {gettext("Get Started Free")}
          </button>
          <button
            phx-click="explore_programs"
            class={[
              "px-8 py-4 bg-white/20 backdrop-blur-sm border-2 border-white text-white hover:bg-white/30",
              Theme.typography(:cta),
              Theme.transition(:normal),
              Theme.rounded(:lg)
            ]}
          >
            {gettext("Explore Programs")}
          </button>
        </:actions>
      </.hero_section>
      
    <!-- Features Section -->
      <div class={Theme.bg(:surface)}>
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 lg:py-24">
          <div class="text-center mb-16">
            <h2 class={[Theme.typography(:page_title), "mb-4", Theme.text_color(:heading)]}>
              {gettext("Why Klass Hero?")}
            </h2>
            <p class={["text-xl", Theme.text_color(:secondary)]}>
              {gettext("Safety, quality, and convenience for modern families.")}
            </p>
          </div>

          <div class="grid md:grid-cols-3 gap-8 lg:gap-12">
            <.feature_card
              gradient_class={Theme.gradient(:cool)}
              icon_path="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
              title={gettext("Safety First")}
              description={
                gettext(
                  "Every provider is rigorously vetted. We prioritize child safety above all else, giving parents peace of mind."
                )
              }
            />
            <.feature_card
              gradient_class={Theme.gradient(:primary)}
              icon_path="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
              title={gettext("Easy Scheduling")}
              description={
                gettext(
                  "Book camps, tutors, and workshops instantly. Our integrated planner helps you manage your child's busy life."
                )
              }
            />
            <.feature_card
              gradient_class={Theme.gradient(:primary)}
              icon_path="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
              title={gettext("Community Focused")}
              description={
                gettext(
                  "Built for the Berlin international community. Connect with local families and trusted educators nearby."
                )
              }
            />
          </div>
        </div>
      </div>
      
    <!-- Featured Programs Section -->
      <div class={[Theme.bg(:muted), "py-16 lg:py-24"]}>
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-12">
            <h2 class={[Theme.typography(:page_title), "mb-4", Theme.text_color(:heading)]}>
              {gettext("Featured Programs")}
            </h2>
            <p class={["text-xl", Theme.text_color(:secondary)]}>
              {gettext("Explore top-rated activities for your children")}
            </p>
          </div>

          <div
            id="featured-programs"
            phx-update="stream"
            class="grid md:grid-cols-3 gap-6 lg:gap-8 mb-8"
          >
            <.program_card_simple
              :for={{dom_id, program} <- @streams.featured_programs}
              id={dom_id}
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
              class={[
                Theme.gradient(:primary),
                "px-8 py-3 text-white hover:shadow-lg transform hover:scale-105",
                Theme.typography(:cta),
                Theme.transition(:normal),
                Theme.rounded(:lg)
              ]}
            >
              {gettext("View All Programs →")}
            </button>
          </div>
        </div>
      </div>
      
    <!-- Social Proof / Trust Section -->
      <div class={Theme.bg(:surface)}>
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 lg:py-24">
          <div class="text-center mb-12">
            <h2 class={[Theme.typography(:page_title), "mb-4", Theme.text_color(:heading)]}>
              {gettext("Trusted by Families Everywhere")}
            </h2>
          </div>

          <div class="grid md:grid-cols-3 gap-8">
            <.stat_display
              value="10,000+"
              label={gettext("Active Families")}
              gradient_class={Theme.gradient(:primary)}
            />
            <.stat_display
              value="500+"
              label={gettext("Programs Available")}
              gradient_class={Theme.gradient(:primary)}
            />
            <.stat_display
              value="4.9/5"
              label={gettext("Average Rating")}
              gradient_class={Theme.gradient(:primary)}
            />
          </div>
        </div>
      </div>
      
    <!-- CTA Section -->
      <div class={[Theme.gradient(:primary), "py-16 lg:py-20"]}>
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 class={[Theme.typography(:page_title), "text-white mb-6"]}>
            {gettext("Ready to Get Started?")}
          </h2>
          <p class="text-xl text-white/90 mb-8">
            {gettext("Join thousands of families discovering amazing afterschool programs")}
          </p>
          <button
            phx-click="get_started"
            class={[
              "px-8 py-4 transform hover:scale-105 shadow-lg",
              Theme.typography(:cta),
              Theme.transition(:normal),
              Theme.rounded(:lg),
              Theme.bg(:surface),
              "hover:#{Theme.bg(:light)}",
              Theme.text_color(:primary)
            ]}
          >
            {gettext("Create Free Account →")}
          </button>
        </div>
      </div>
    </div>
    """
  end
end
