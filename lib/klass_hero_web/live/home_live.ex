defmodule KlassHeroWeb.HomeLive do
  use KlassHeroWeb, :live_view

  import KlassHeroWeb.ProgramComponents
  import KlassHeroWeb.UIComponents

  alias KlassHero.ProgramCatalog
  alias KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListing
  alias KlassHeroWeb.Presenters.ProgramPresenter
  alias KlassHeroWeb.Theme

  @impl true
  def mount(_params, _session, socket) do
    featured = ProgramCatalog.list_featured_programs()
    featured_maps = Enum.map(featured, &listing_to_card_map/1)
    trending_tags = ProgramCatalog.trending_searches()

    socket =
      socket
      |> assign(
        page_title: gettext("Klass Hero - Connecting Families with Trusted Youth Educators"),
        # Retained for pricing section re-enablement (#178)
        pricing_tab: :families,
        trending_tags: trending_tags
      )
      |> stream(:featured_programs, featured_maps)
      |> assign(:featured_empty?, Enum.empty?(featured))

    {:ok, socket}
  end

  @impl true
  def handle_event("explore_programs", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/programs")}
  end

  # Retained for pricing section re-enablement (#178)
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

  # Converts a ProgramListing read model into the map shape expected by program_card
  defp listing_to_card_map(%ProgramListing{} = program) do
    %{
      id: program.id,
      title: program.title,
      description: program.description,
      category: ProgramPresenter.format_category_for_display(program.category),
      age_range: program.age_range,
      price: ProgramPresenter.safe_decimal_to_float(program.price),
      period: program.pricing_period,
      cover_image_url: program.cover_image_url,
      meeting_days: program.meeting_days || [],
      meeting_start_time: program.meeting_start_time,
      meeting_end_time: program.meeting_end_time,
      start_date: program.start_date,
      end_date: program.end_date,
      spots_left: nil,
      gradient_class: Theme.gradient(:primary),
      icon_name: ProgramPresenter.icon_name(program.category)
    }
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
          <p class="text-lg text-hero-black mb-6 max-w-2xl mx-auto">
            {gettext("Berlin's leading network for tutors, coaches, and camp providers!")}
          </p>
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
          <div phx-hook="ScrollReveal" id="featured-heading" class="text-center mb-12">
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
            <.program_card
              :for={{dom_id, program} <- @streams.featured_programs}
              id={dom_id}
              program={program}
              variant={:compact}
              phx-click="view_program"
              phx-value-program-id={program.id}
            />
          </div>

          <div phx-hook="ScrollReveal" id="featured-cta" class="text-center">
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
          <div phx-hook="ScrollReveal" id="features-heading" class="text-center mb-12">
            <div class="text-center mb-4">
              <.section_label>{gettext("For Families")}</.section_label>
            </div>
            <h2 class={[Theme.typography(:page_title), "mb-4", Theme.text_color(:heading)]}>
              {gettext("Why Klass Hero?")}
            </h2>
            <p class={["text-xl", Theme.text_color(:secondary)]}>
              {gettext("Safety, quality, and convenience for modern families.")}
            </p>
          </div>

          <div
            phx-hook="ScrollReveal"
            id="features-grid"
            data-reveal-stagger="150"
            class="grid md:grid-cols-3 gap-8 lg:gap-12"
          >
            <.feature_card
              gradient_class={Theme.gradient(:cool)}
              icon="hero-shield-check"
              title={gettext("Safety First")}
              description={
                gettext(
                  "Every provider is rigorously vetted. We prioritize child safety above all else, giving parents peace of mind."
                )
              }
            />
            <.feature_card
              gradient_class={Theme.gradient(:primary)}
              icon="hero-calendar-days"
              title={gettext("Easy Scheduling")}
              description={
                gettext(
                  "Book camps, tutors, and workshops instantly. Our integrated planner helps you manage your child's busy life."
                )
              }
            />
            <.feature_card
              gradient_class={Theme.gradient(:primary)}
              icon="hero-user-group"
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
          <div phx-hook="ScrollReveal" id="providers-heading" class="text-center mb-12">
            <div class="text-center mb-4">
              <.section_label>{gettext("For Providers")}</.section_label>
            </div>

            <h2 class={[Theme.typography(:page_title), "mb-4", Theme.text_color(:heading)]}>
              {gettext("How to Grow Your Youth Program: Let's Build Together.")}
            </h2>
            <p class={["text-xl", Theme.text_color(:secondary)]}>
              {gettext(
                "Join our community of passionate educators. Tools and support to help you succeed."
              )}
            </p>
          </div>
          
    <!-- Provider Steps Grid -->
          <div
            phx-hook="ScrollReveal"
            id="providers-grid"
            data-reveal-stagger="150"
            class="grid md:grid-cols-3 gap-6 lg:gap-8 mb-8"
          >
            <.provider_step_card
              step_number={1}
              title={gettext("Create a Program")}
              description={
                gettext(
                  "Set up your teaching profile and list your programs in minutes. Share your expertise with families who need it."
                )
              }
              icon="hero-pencil-square"
            />
            <.provider_step_card
              step_number={2}
              title={gettext("Deliver Quality")}
              description={
                gettext(
                  "Teach your passion with our tools for scheduling, communication, and progress tracking."
                )
              }
              icon="hero-trophy"
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
          <div phx-hook="ScrollReveal" id="providers-cta" class="text-center">
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

      <%!-- HIDDEN: Pricing section hidden until transactions are live (#178). Uncomment to re-enable.

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

    --%>
      
    <!-- Founder Section - trust signal for parents (#179) -->
      <div id="founder-section" class={[Theme.bg(:surface), "py-16 lg:py-24"]}>
        <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <div class="mb-12">
            <.section_label>{gettext("Our Story")}</.section_label>
            <h2 class={[Theme.typography(:page_title), "mb-4", Theme.text_color(:heading)]}>
              {gettext("Built by Parents to Empower Educators.")}
            </h2>
            <p class={["text-lg leading-relaxed", Theme.text_color(:secondary)]}>
              {gettext(
                "As fathers and partners of teachers in Berlin, we saw and heard firsthand how hard it is to find, book, and manage quality youth activities outside the classroom. Klass Hero is the complete platform connecting Berlin families and schools with trusted, vetted activity providers — offering safe, supervised, and enriching experiences across sports, arts, tutoring, and more. We verify every provider, structure every booking, and support every step — so parents know their child is in good hands, and providers can focus on what they do best: inspiring kids."
              )}
            </p>
          </div>
          <.link
            navigate={~p"/about"}
            class={[
              Theme.gradient(:primary),
              "inline-block px-8 py-3 text-white hover:shadow-lg transform hover:scale-105",
              Theme.typography(:cta),
              Theme.transition(:normal),
              Theme.rounded(:lg)
            ]}
          >
            {gettext("Read our founding story →")}
          </.link>
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
              question={gettext("How does the 6-step provider vetting process work?")}
              answer={
                gettext(
                  "Every provider completes identity and age verification, experience validation, an extended background check, video screening, child safeguarding training, and agreement to our Community Guidelines before being approved."
                )
              }
            />

            <.faq_item
              id="faq-2"
              question={gettext("Can I list my programs on Klass Hero and what does it cost?")}
            >
              <p class="mb-3">{gettext("Yes! Register for free and start listing immediately.")}</p>
              <p class="font-semibold mb-1">{gettext("What You Can List:")}</p>
              <ul class="list-disc list-inside mb-3 space-y-1">
                <li>{gettext("Regular classes and courses (weekly/monthly)")}</li>
                <li>{gettext("Camps and holiday programs")}</li>
                <li>{gettext("Workshops and one-time events")}</li>
                <li>{gettext("Private lessons and tutoring")}</li>
              </ul>
              <p class="font-semibold mb-1">{gettext("Pricing:")}</p>
              <ul class="list-disc list-inside mb-3 space-y-1">
                <li>
                  {gettext(
                    "Starter: Free to join — no registration fees, no monthly subscriptions. 20% commission per booking"
                  )}
                </li>
                <li>
                  {gettext(
                    "Professional: More tools and opportunities for €9/month + 12% per booking (only when you get bookings)"
                  )}
                </li>
                <li>
                  {gettext(
                    "Business Account: €39/month + 6% per booking (for providers/teams earning €600+/month)"
                  )}
                </li>
              </ul>
              <p class="font-semibold mb-1">{gettext("Example: If you earn €1,000 in bookings")}</p>
              <ul class="list-disc list-inside mb-3 space-y-1">
                <li>{gettext("Starter: You keep €800 (€200 commission)")}</li>
                <li>{gettext("Professional: You keep €871 (€120 commission + €9 monthly fee)")}</li>
                <li>
                  {gettext("Business Account: You keep €901 (€60 commission + €39 monthly fee)")}
                </li>
              </ul>
              <p class="mt-3">
                {gettext(
                  "All plans include: Profile page, booking system, payment processing, messaging, and marketing to Berlin families."
                )}
              </p>
            </.faq_item>

            <.faq_item
              id="faq-3"
              question={gettext("How does the booking system work?")}
            >
              <p class="mb-3">{gettext("Simple and automated - we handle everything.")}</p>
              <p class="font-semibold mb-1">{gettext("When Someone Books:")}</p>
              <ol class="list-decimal list-inside mb-3 space-y-1">
                <li>{gettext("Parent books and pays through Klass Hero (via Stripe)")}</li>
                <li>
                  {gettext("You receive instant email with booking details and parent contact info")}
                </li>
                <li>{gettext("Parent receives confirmation with your contact details")}</li>
                <li>{gettext("Funds are immediately available in your Klass Hero account")}</li>
                <li>{gettext("You deliver the program")}</li>
              </ol>
              <p class="font-semibold mb-1">{gettext("Payment Options for Parents:")}</p>
              <ul class="list-disc list-inside mb-3 space-y-1">
                <li>{gettext("Credit/debit card (Visa, Mastercard, Amex)")}</li>
                <li>{gettext("Apple Pay / Google Pay")}</li>
                <li>{gettext("SEPA direct debit")}</li>
                <li>{gettext("Klarna (pay later options)")}</li>
              </ul>
              <p class="mb-3">{gettext("All payments processed securely through Stripe.")}</p>
              <p class="font-semibold mb-1">{gettext("How You Get Paid:")}</p>
              <ul class="list-disc list-inside mb-3 space-y-1">
                <li>
                  {gettext(
                    "Instant availability: Funds are in your Klass Hero balance immediately after booking"
                  )}
                </li>
                <li>{gettext("Weekly payouts: Transferred to your bank account every Friday")}</li>
                <li>{gettext("Or: Request instant payout anytime (minimum €50)")}</li>
                <li>{gettext("Platform fee automatically deducted when parent pays")}</li>
              </ul>
              <p class="font-semibold mb-1">{gettext("Why This Works Better:")}</p>
              <ul class="list-disc list-inside mb-3 space-y-1">
                <li>{gettext("You get paid BEFORE delivering the program (no waiting)")}</li>
                <li>{gettext("Parents pay upfront when booking (reduces no-shows by 85%)")}</li>
                <li>{gettext("No chasing payments or sending invoices")}</li>
                <li>{gettext("No risk of non-payment")}</li>
                <li>{gettext("Automatic fee calculation (no surprises)")}</li>
              </ul>
              <p class="font-semibold mb-1">{gettext("Track Everything:")}</p>
              <ul class="list-disc list-inside space-y-1">
                <li>{gettext("Real-time dashboard shows all bookings and available balance")}</li>
                <li>{gettext("Export participant lists anytime")}</li>
                <li>{gettext("See payment history and upcoming payouts")}</li>
                <li>{gettext("Download monthly statements for taxes")}</li>
              </ul>
            </.faq_item>

            <.faq_item
              id="faq-4"
              question={gettext("What happens if a parent cancels or I need to cancel?")}
            >
              <p class="mb-3">{gettext("Clear policies protect everyone.")}</p>
              <p class="font-semibold mb-1">{gettext("If Parent Cancels:")}</p>
              <p class="mb-3">
                {gettext(
                  "Contact them immediately - often you can find an alternative date. Include us in CC/BCC (support@mail.klasshero.com) so we're informed."
                )}
              </p>
              <p class="mb-1">{gettext("Refunds are automatic based on our cancellation policy:")}</p>
              <ul class="list-disc list-inside mb-3 space-y-1">
                <li>{gettext("7+ days before: Usually full refund (you keep nothing)")}</li>
                <li>{gettext("3-7 days before: Usually 75% refund (you keep 25%)")}</li>
                <li>{gettext("Less than 3 days: Usually 25-50% refund (you keep 50-75%)")}</li>
              </ul>
              <p class="mb-3">
                {gettext(
                  "Stripe processes all refunds - funds returned to parent's original payment method within 5-10 business days. Any amounts you keep remain in your balance."
                )}
              </p>
              <p class="font-semibold mb-1">{gettext("If You Must Cancel:")}</p>
              <p class="mb-3">
                {gettext(
                  "Contact all booked parents immediately and offer alternative dates. Include us in CC/BCC (support@mail.klasshero.com)."
                )}
              </p>
              <p class="mb-3">
                {gettext(
                  "When you cancel, parents get 100% refund automatically. The amount is deducted from your next payout."
                )}
              </p>
              <p class="font-semibold mb-1">{gettext("Provider Cancellation Penalties:")}</p>
              <ul class="list-disc list-inside mb-3 space-y-1">
                <li>{gettext("1st cancellation (90 days): Warning only")}</li>
                <li>{gettext("2nd cancellation: €50 penalty")}</li>
                <li>{gettext("3rd cancellation: €100 penalty + 14-day suspension")}</li>
                <li>{gettext("4+ cancellations: Account termination")}</li>
              </ul>
              <p class="font-semibold mb-1">{gettext("No penalties for legitimate reasons:")}</p>
              <ul class="list-disc list-inside mb-3 space-y-1">
                <li>{gettext("Medical emergency")}</li>
                <li>{gettext("Death in family")}</li>
                <li>{gettext("Severe weather")}</li>
                <li>{gettext("Government closure")}</li>
                <li>{gettext("Minimum enrollment not met (camps only - notify 14 days before)")}</li>
              </ul>
              <p class="font-semibold mb-1">{gettext("Provider No-Show:")}</p>
              <p class="mb-1">{gettext("If you fail to show up without prior notice:")}</p>
              <ul class="list-disc list-inside mb-3 space-y-1">
                <li>{gettext("Immediate account suspension")}</li>
                <li>{gettext("€200 penalty (deducted from balance or invoiced)")}</li>
                <li>{gettext("Parent gets 100% refund + family credit")}</li>
                <li>{gettext("Permanent ban if no valid emergency")}</li>
              </ul>
              <p>
                {gettext(
                  "Keep your reliability high - parents can see your cancellation rate on your profile."
                )}
              </p>
            </.faq_item>

            <.faq_item
              id="faq-5"
              question={gettext("Is Klass Hero free for parents to use?")}
              answer={
                gettext(
                  "Yes! Browsing and booking are completely free. No subscription, no booking fees."
                )
              }
            />

            <.faq_item
              id="faq-6"
              question={gettext("Do I need an account to book?")}
              answer={
                gettext(
                  "Yes, you need a free account to complete a booking and manage your reservations."
                )
              }
            />

            <.faq_item
              id="faq-7"
              question={gettext("Can I change my booking date?")}
              answer={
                gettext(
                  "Contact the provider directly (details in confirmation email). Most providers are flexible if you ask in advance."
                )
              }
            />

            <.faq_item
              id="faq-8"
              question={gettext("What if my child gets sick?")}
              answer={
                gettext(
                  "Email the provider and us (support@mail.klasshero.com) immediately. You may qualify for full refund."
                )
              }
            />

            <.faq_item
              id="faq-9"
              question={gettext("Can I get a refund if the provider cancels?")}
              answer={gettext("Yes, always 100% refund if provider cancels. No exceptions.")}
            />

            <.faq_item
              id="faq-10"
              question={gettext("What if the provider doesn't show up?")}
              answer={
                gettext(
                  "Contact us immediately at support@mail.klasshero.com or call +49 (0) 152 2426 0416. You'll receive 100% refund + family credit, and the provider faces serious penalties."
                )
              }
            />

            <.faq_item
              id="faq-11"
              question={gettext("Where is Klass Hero available?")}
              answer={
                gettext(
                  "Currently serving Berlin, with expansion to other German cities coming soon."
                )
              }
            />

            <.faq_item
              id="faq-12"
              question={gettext("Can I buy a gift voucher?")}
              answer={
                gettext(
                  "Coming soon! Sign up for our newsletter to be notified when gift vouchers launch."
                )
              }
            />

            <.faq_item
              id="faq-13"
              question={gettext("What types of activities can I find on Klass Hero?")}
              answer={
                gettext(
                  "Tutoring (math, English, German, science), music lessons (piano, guitar, violin), sports coaching (football, tennis, swimming), arts & crafts, STEM workshops, language classes, summer camps, and after-school programmes — all in Berlin."
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
