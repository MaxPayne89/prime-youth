defmodule KlassHeroWeb.HomeLive do
  use KlassHeroWeb, :live_view

  import KlassHeroWeb.UIComponents

  alias KlassHero.ProgramCatalog
  alias KlassHeroWeb.Theme

  @impl true
  def mount(_params, _session, socket) do
    featured = ProgramCatalog.list_featured_programs()
    trending_tags = ProgramCatalog.trending_searches()

    socket =
      socket
      |> assign(
        page_title: gettext("Klass Hero - Connecting Families with Trusted Youth Educators"),
        pricing_tab: :families,
        trending_tags: trending_tags
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
  def handle_event("switch_pricing_tab", %{"tab" => tab}, socket) do
    pricing_tab = String.to_existing_atom(tab)
    {:noreply, assign(socket, :pricing_tab, pricing_tab)}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    query = String.trim(query)

    if query == "" do
      {:noreply, socket}
    else
      {:noreply, push_navigate(socket, to: ~p"/programs?q=#{query}")}
    end
  end

  @impl true
  def handle_event("tag_search", %{"tag" => tag}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/programs?q=#{tag}")}
  end

  @impl true
  def handle_event("view_program", %{"program-id" => program_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/programs/#{program_id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <!-- Hero Section -->
      <.hero_section variant="landing" show_wave={false}>
        <:title>
          <span class="text-hero-grey-600">Connecting Families with Trusted</span>
          <br />
          <span class="text-hero-black">Heroes for Our Youth</span>
        </:title>
        <:subtitle>
          <p class="text-lg text-hero-grey-600 max-w-2xl mx-auto">
            {gettext("Klass Hero is Berlin's leading marketplace for")}
            <strong class="text-hero-black">{gettext(" youth education, sports, and recreational activities")}</strong>. {gettext(
              " Find verified tutors, coaches, and camps near you."
            )}
          </p>
        </:subtitle>
        <:search_bar>
          <form id="home-search-form" phx-submit="search" class="max-w-3xl mx-auto mb-8">
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
                  name="search"
                  placeholder={gettext("Search for programs...")}
                  class="w-full outline-none text-hero-black bg-transparent"
                />
              </div>
              <button
                type="submit"
                class="bg-hero-yellow-400 text-hero-black px-6 py-3 rounded-full font-semibold hover:bg-hero-yellow-500 transition-all duration-200"
              >
                {gettext("Search")}
              </button>
            </div>
          </form>
        </:search_bar>
        <:trending_tags>
          <div class="flex flex-wrap items-center justify-center gap-2">
            <span class="text-sm text-hero-grey-600 font-medium">
              {gettext("Trending in Berlin:")}
            </span>
            <button
              :for={tag <- @trending_tags}
              type="button"
              phx-click="tag_search"
              phx-value-tag={tag}
              class="px-4 py-2 bg-white/80 backdrop-blur-sm rounded-full text-sm text-hero-black border border-hero-grey-200 hover:bg-white hover:shadow-sm transition-all duration-200"
            >
              {tag}
            </button>
          </div>
        </:trending_tags>
      </.hero_section>
      
    <!-- Featured Programs Section -->
      <div id="featured-programs-section" class={[Theme.bg(:muted), "py-16 lg:py-24"]}>
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
            class="grid md:grid-cols-3 gap-6 lg:gap-8 mb-8 items-stretch"
          >
            <.program_card_simple
              :for={{dom_id, program} <- @streams.featured_programs}
              id={dom_id}
              gradient_class={Theme.gradient(:program_default)}
              icon_path={program.icon_path}
              title={program.title}
              description={program.description}
              price={program.price}
              phx-click="view_program"
              phx-value-program-id={program.id}
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
      
    <!-- Features Section -->
      <div id="why-klass-hero-section" class={Theme.bg(:surface)}>
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
      
    <!-- Grow Your Passion Business Section -->
      <div id="grow-passion-business-section" class={[Theme.bg(:muted), "py-16 lg:py-24"]}>
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <!-- Label Badge -->
          <div class="text-center mb-4">
            <span class={[
              "inline-block px-4 py-1.5 text-sm font-medium",
              Theme.gradient(:primary),
              "text-white",
              Theme.rounded(:full)
            ]}>
              {gettext("For Providers")}
            </span>
          </div>
          
    <!-- Section Heading -->
          <div class="text-center mb-12">
            <h2 class={[Theme.typography(:page_title), "mb-4", Theme.text_color(:heading)]}>
              {gettext("Grow Your Passion Business")}
            </h2>
            <p class={["text-xl", Theme.text_color(:secondary)]}>
              {gettext(
                "Join our community of passionate educators. Tools and support to help you succeed."
              )}
            </p>
          </div>
          
    <!-- Provider Steps Grid -->
          <div class="grid md:grid-cols-3 gap-6 lg:gap-8 mb-8">
            <.provider_step_card
              step_number={1}
              title={gettext("Create a Program")}
              description={
                gettext(
                  "Set up your teaching profile and list your programs in minutes. Share your expertise with families who need it."
                )
              }
              icon="hero-clipboard-document-list"
            />
            <.provider_step_card
              step_number={2}
              title={gettext("Deliver Quality")}
              description={
                gettext(
                  "Teach your passion with our tools for scheduling, communication, and progress tracking."
                )
              }
              icon="hero-chat-bubble-left-right"
            />
            <.provider_step_card
              step_number={3}
              title={gettext("Get Paid & Grow")}
              description={
                gettext(
                  "Secure payments, insights into your business, and opportunities to expand your impact."
                )
              }
              icon="hero-arrow-trending-up"
            />
          </div>
          
    <!-- CTA Button -->
          <div class="text-center">
            <button class={[
              "bg-hero-yellow-400 text-hero-black px-8 py-3 font-semibold hover:bg-hero-yellow-500",
              Theme.transition(:normal),
              Theme.rounded(:lg),
              "hover:shadow-lg transform hover:scale-105"
            ]}>
              {gettext("Start Teaching Today →")}
            </button>
          </div>
        </div>
      </div>
      
    <!-- Simple, Transparent Pricing Section -->
      <div id="pricing-section" class={[Theme.bg(:surface), "py-16 lg:py-24"]}>
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <!-- Section Heading -->
          <div class="text-center mb-12">
            <h2 class={[Theme.typography(:page_title), "mb-4", Theme.text_color(:heading)]}>
              {gettext("Simple, Transparent Pricing")}
            </h2>
            <p class={["text-xl", Theme.text_color(:secondary)]}>
              {gettext("Choose the plan that fits your needs")}
            </p>
          </div>
          
    <!-- Tab Toggle -->
          <div class="flex justify-center mb-12">
            <div class={[
              "inline-flex",
              Theme.rounded(:lg),
              "p-1",
              Theme.bg(:muted)
            ]}>
              <button
                phx-click="switch_pricing_tab"
                phx-value-tab="families"
                class={[
                  "px-6 py-2.5 text-sm font-medium",
                  Theme.rounded(:lg),
                  Theme.transition(:fast),
                  if(@pricing_tab == :families,
                    do: [
                      Theme.gradient(:primary),
                      "text-white shadow-md"
                    ],
                    else: [
                      "text-hero-grey-600 hover:text-hero-grey-900"
                    ]
                  )
                ]}
              >
                {gettext("For Families")}
              </button>
              <button
                phx-click="switch_pricing_tab"
                phx-value-tab="providers"
                class={[
                  "px-6 py-2.5 text-sm font-medium",
                  Theme.rounded(:lg),
                  Theme.transition(:fast),
                  if(@pricing_tab == :providers,
                    do: [
                      Theme.gradient(:primary),
                      "text-white shadow-md"
                    ],
                    else: [
                      "text-hero-grey-600 hover:text-hero-grey-900"
                    ]
                  )
                ]}
              >
                {gettext("For Providers")}
              </button>
            </div>
          </div>
          
    <!-- Pricing Cards Grid -->
          <div class="grid md:grid-cols-2 gap-8 lg:gap-12 mb-8">
            <%= if @pricing_tab == :families do %>
              <!-- Explorer Family Plan -->
              <.pricing_card
                title={gettext("Explorer Family")}
                subtitle={gettext("Perfect for getting started")}
                price={gettext("Free")}
                period={gettext("forever")}
                features={[
                  gettext("Browse all programs"),
                  gettext("Book up to 2 activities per month"),
                  gettext("Read and write reviews"),
                  gettext("Join the community")
                ]}
                cta_text={gettext("Start Exploring")}
              />
              
    <!-- Active Family Plan (Popular) -->
              <.pricing_card
                title={gettext("Active Family")}
                subtitle={gettext("For families who love activities")}
                price="€8"
                period={gettext("month")}
                popular
                features={[
                  gettext("AI Support Bot for recommendations"),
                  gettext("Unlimited bookings"),
                  gettext("Progress tracking dashboard"),
                  gettext("Direct messaging with providers"),
                  gettext("1 free cancellation per month")
                ]}
                cta_text={gettext("Get Started")}
              />
            <% else %>
              <!-- Starter Provider Plan -->
              <.pricing_card
                title={gettext("Starter Provider")}
                subtitle={gettext("Begin your teaching journey")}
                price={gettext("Free")}
                period={gettext("forever")}
                features={[
                  gettext("Basic profile page"),
                  gettext("List up to 3 programs"),
                  gettext("Accept bookings"),
                  gettext("Basic analytics")
                ]}
                cta_text={gettext("Start Teaching")}
              />
              
    <!-- Pro Provider Plan (Popular) -->
              <.pricing_card
                title={gettext("Pro Provider")}
                subtitle={gettext("For serious educators")}
                price="€15"
                period={gettext("month")}
                popular
                features={[
                  gettext("Unlimited program listings"),
                  gettext("Advanced analytics dashboard"),
                  gettext("Priority customer support"),
                  gettext("Featured placement opportunities")
                ]}
                cta_text={gettext("Go Pro")}
              />
            <% end %>
          </div>
          
    <!-- Footer Link -->
          <div class="text-center">
            <a
              href="#"
              class={[
                "text-sm",
                Theme.text_color(:secondary),
                "hover:underline",
                Theme.transition(:fast)
              ]}
            >
              {gettext("Compare all plan features details →")}
            </a>
          </div>
        </div>
      </div>
      
    <!-- Frequently Asked Questions Section -->
      <div id="faq-section" class={[Theme.bg(:muted), "py-16 lg:py-24"]}>
        <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
          <!-- Section Heading -->
          <div class="text-center mb-12">
            <h2 class={[Theme.typography(:page_title), "mb-4", Theme.text_color(:heading)]}>
              {gettext("Frequently Asked Questions")}
            </h2>
            <p class={["text-xl", Theme.text_color(:secondary)]}>
              {gettext("Everything you need to know about Klass Hero")}
            </p>
          </div>
          
    <!-- FAQ Items -->
          <div class="space-y-4">
            <.faq_item
              id="faq-1"
              question={gettext("How does the 4-step provider vetting process work?")}
              answer={
                gettext(
                  "We verify credentials, conduct background checks, check references, and perform a personal interview before approving any provider."
                )
              }
            />

            <.faq_item
              id="faq-2"
              question={gettext("Is there a free trial for the Active Family plan?")}
              answer={
                gettext(
                  "Yes! New families get a 14-day free trial of the Active Family plan with full access to all features."
                )
              }
            />

            <.faq_item
              id="faq-3"
              question={gettext("Can I cancel a booking?")}
              answer={
                gettext(
                  "Explorer Family members can cancel up to 48 hours before. Active Family members get 1 free same-day cancellation per month."
                )
              }
            />

            <.faq_item
              id="faq-4"
              question={gettext("Do you offer programs for adults?")}
              answer={
                gettext(
                  "Currently, Klass Hero focuses exclusively on youth education and activities for children ages 3-18."
                )
              }
            />

            <.faq_item
              id="faq-5"
              question={gettext("What are Klass Points?")}
              answer={
                gettext(
                  "Klass Points are rewards you earn for bookings, reviews, and referrals. Redeem them for discounts on future programs."
                )
              }
            />
          </div>
        </div>
      </div>
    </div>
    """
  end
end
