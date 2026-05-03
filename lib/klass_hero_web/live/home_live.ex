defmodule KlassHeroWeb.HomeLive do
  use KlassHeroWeb, :live_view

  import KlassHeroWeb.MarketingComponents

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
        trending_tags: trending_tags,
        active_nav: :home
      )
      |> stream(:featured_programs, featured_maps)

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

  # Converts a ProgramListing read model into the map shape expected by mk_program_card
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
      gradient_class: Theme.gradient(:primary),
      icon_name: ProgramPresenter.icon_name(program.category)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.mk_hero trending_tags={@trending_tags} />

    <.mk_featured stream={@streams.featured_programs} />

    <.mk_features />

    <.mk_provider_cta />

    <.mk_founder />

    <.mk_faq subtitle={gettext("Everything you need to know about Klass Hero.")}>
      <.mk_faq_item
        id="faq-1"
        question={gettext("How does the 6-step provider vetting process work?")}
      >
        <p>
          {gettext(
            "Every provider completes identity and age verification, experience validation, an extended background check, video screening, child safeguarding training, and agreement to our Community Guidelines before being approved."
          )}
        </p>
      </.mk_faq_item>

      <.mk_faq_item
        id="faq-2"
        question={gettext("Can I list my programs on Klass Hero and what does it cost?")}
      >
        <p class="mb-3">{gettext("Yes! Register for free and start listing immediately.")}</p>
        <p class="font-semibold mb-1 text-hero-black">{gettext("What You Can List:")}</p>
        <ul class="list-disc list-inside mb-3 space-y-1">
          <li>{gettext("Regular classes and courses (weekly/monthly)")}</li>
          <li>{gettext("Camps and holiday programs")}</li>
          <li>{gettext("Workshops and one-time events")}</li>
          <li>{gettext("Private lessons and tutoring")}</li>
        </ul>
        <p class="font-semibold mb-1 text-hero-black">{gettext("Pricing:")}</p>
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
        <p class="font-semibold mb-1 text-hero-black">
          {gettext("Example: If you earn €1,000 in bookings")}
        </p>
        <ul class="list-disc list-inside mb-3 space-y-1">
          <li>{gettext("Starter: You keep €800 (€200 commission)")}</li>
          <li>{gettext("Professional: You keep €871 (€120 commission + €9 monthly fee)")}</li>
          <li>{gettext("Business Account: You keep €901 (€60 commission + €39 monthly fee)")}</li>
        </ul>
        <p class="mt-3">
          {gettext(
            "All plans include: Profile page, booking system, payment processing, messaging, and marketing to Berlin families."
          )}
        </p>
      </.mk_faq_item>

      <.mk_faq_item id="faq-3" question={gettext("How does the booking system work?")}>
        <p class="mb-3">{gettext("Simple and automated - we handle everything.")}</p>
        <p class="font-semibold mb-1 text-hero-black">{gettext("When Someone Books:")}</p>
        <ol class="list-decimal list-inside mb-3 space-y-1">
          <li>{gettext("Parent books and pays through Klass Hero (via Stripe)")}</li>
          <li>{gettext("You receive instant email with booking details and parent contact info")}</li>
          <li>{gettext("Parent receives confirmation with your contact details")}</li>
          <li>{gettext("Funds are immediately available in your Klass Hero account")}</li>
          <li>{gettext("You deliver the program")}</li>
        </ol>
        <p class="font-semibold mb-1 text-hero-black">{gettext("Payment Options for Parents:")}</p>
        <ul class="list-disc list-inside mb-3 space-y-1">
          <li>{gettext("Credit/debit card (Visa, Mastercard, Amex)")}</li>
          <li>{gettext("Apple Pay / Google Pay")}</li>
          <li>{gettext("SEPA direct debit")}</li>
          <li>{gettext("Klarna (pay later options)")}</li>
        </ul>
        <p class="mb-3">{gettext("All payments processed securely through Stripe.")}</p>
        <p class="font-semibold mb-1 text-hero-black">{gettext("How You Get Paid:")}</p>
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
        <p class="font-semibold mb-1 text-hero-black">{gettext("Why This Works Better:")}</p>
        <ul class="list-disc list-inside mb-3 space-y-1">
          <li>{gettext("You get paid BEFORE delivering the program (no waiting)")}</li>
          <li>{gettext("Parents pay upfront when booking (reduces no-shows by 85%)")}</li>
          <li>{gettext("No chasing payments or sending invoices")}</li>
          <li>{gettext("No risk of non-payment")}</li>
          <li>{gettext("Automatic fee calculation (no surprises)")}</li>
        </ul>
        <p class="font-semibold mb-1 text-hero-black">{gettext("Track Everything:")}</p>
        <ul class="list-disc list-inside space-y-1">
          <li>{gettext("Real-time dashboard shows all bookings and available balance")}</li>
          <li>{gettext("Export participant lists anytime")}</li>
          <li>{gettext("See payment history and upcoming payouts")}</li>
          <li>{gettext("Download monthly statements for taxes")}</li>
        </ul>
      </.mk_faq_item>

      <.mk_faq_item
        id="faq-4"
        question={gettext("What happens if a parent cancels or I need to cancel?")}
      >
        <p class="mb-3">{gettext("Clear policies protect everyone.")}</p>
        <p class="font-semibold mb-1 text-hero-black">{gettext("If Parent Cancels:")}</p>
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
        <p class="font-semibold mb-1 text-hero-black">{gettext("If You Must Cancel:")}</p>
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
        <p class="font-semibold mb-1 text-hero-black">
          {gettext("Provider Cancellation Penalties:")}
        </p>
        <ul class="list-disc list-inside mb-3 space-y-1">
          <li>{gettext("1st cancellation (90 days): Warning only")}</li>
          <li>{gettext("2nd cancellation: €50 penalty")}</li>
          <li>{gettext("3rd cancellation: €100 penalty + 14-day suspension")}</li>
          <li>{gettext("4+ cancellations: Account termination")}</li>
        </ul>
        <p class="font-semibold mb-1 text-hero-black">
          {gettext("No penalties for legitimate reasons:")}
        </p>
        <ul class="list-disc list-inside mb-3 space-y-1">
          <li>{gettext("Medical emergency")}</li>
          <li>{gettext("Death in family")}</li>
          <li>{gettext("Severe weather")}</li>
          <li>{gettext("Government closure")}</li>
          <li>{gettext("Minimum enrollment not met (camps only - notify 14 days before)")}</li>
        </ul>
        <p class="font-semibold mb-1 text-hero-black">{gettext("Provider No-Show:")}</p>
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
      </.mk_faq_item>

      <.mk_faq_item id="faq-5" question={gettext("Is Klass Hero free for parents to use?")}>
        <p>
          {gettext("Yes! Browsing and booking are completely free. No subscription, no booking fees.")}
        </p>
      </.mk_faq_item>

      <.mk_faq_item id="faq-6" question={gettext("Do I need an account to book?")}>
        <p>
          {gettext("Yes, you need a free account to complete a booking and manage your reservations.")}
        </p>
      </.mk_faq_item>

      <.mk_faq_item id="faq-7" question={gettext("Can I change my booking date?")}>
        <p>
          {gettext(
            "Contact the provider directly (details in confirmation email). Most providers are flexible if you ask in advance."
          )}
        </p>
      </.mk_faq_item>

      <.mk_faq_item id="faq-8" question={gettext("What if my child gets sick?")}>
        <p>
          {gettext(
            "Email the provider and us (support@mail.klasshero.com) immediately. You may qualify for full refund."
          )}
        </p>
      </.mk_faq_item>

      <.mk_faq_item id="faq-9" question={gettext("Can I get a refund if the provider cancels?")}>
        <p>{gettext("Yes, always 100% refund if provider cancels. No exceptions.")}</p>
      </.mk_faq_item>

      <.mk_faq_item id="faq-10" question={gettext("What if the provider doesn't show up?")}>
        <p>
          {gettext(
            "Contact us immediately at support@mail.klasshero.com or call +49 (0) 152 2426 0416. You'll receive 100% refund + family credit, and the provider faces serious penalties."
          )}
        </p>
      </.mk_faq_item>

      <.mk_faq_item id="faq-11" question={gettext("Where is Klass Hero available?")}>
        <p>
          {gettext("Currently serving Berlin, with expansion to other German cities coming soon.")}
        </p>
      </.mk_faq_item>

      <.mk_faq_item id="faq-12" question={gettext("Can I buy a gift voucher?")}>
        <p>
          {gettext(
            "Coming soon! Sign up for our newsletter to be notified when gift vouchers launch."
          )}
        </p>
      </.mk_faq_item>
    </.mk_faq>
    """
  end
end
