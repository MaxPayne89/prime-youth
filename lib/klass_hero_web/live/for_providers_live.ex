defmodule KlassHeroWeb.ForProvidersLive do
  use KlassHeroWeb, :live_view

  alias KlassHero.Shared.Entitlements
  alias KlassHeroWeb.Theme

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("For Providers"),
       provider_tiers: Entitlements.all_provider_tiers()
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white">
      <.dark_hero />
      <.benefits_section benefits={benefits()} />
      <.how_it_works_section steps={steps()} />
      <.pricing_section tiers={pricing_tiers(@provider_tiers)} />
      <.faq_section faqs={faqs()} />
    </div>
    """
  end

  ## ---------------------------------------------------------------------------
  ## Sections
  ## ---------------------------------------------------------------------------

  defp dark_hero(assigns) do
    ~H"""
    <section
      id="for-providers-hero"
      class="relative overflow-hidden bg-black text-white pt-20 pb-28 lg:pt-28 lg:pb-36"
    >
      <div class="absolute -top-20 -right-20 w-[28rem] h-[28rem] rounded-full bg-hero-blue-500 opacity-15 blur-3xl">
      </div>
      <div class="absolute -bottom-20 -left-20 w-[28rem] h-[28rem] rounded-full bg-hero-yellow-500 opacity-15 blur-3xl">
      </div>
      <div class="relative max-w-6xl mx-auto px-6 text-center">
        <.kh_pill tone={:accent} class="mb-6">{gettext("For Providers")}</.kh_pill>
        <%!-- typography-lint-ignore: marketing hero override using fluid clamp size for impact --%>
        <h1 class="text-white font-display font-extrabold tracking-tight text-[clamp(40px,6vw,76px)] leading-[1.02]">
          {gettext("Teach more.")}<br />
          <span class="bg-hero-yellow-500 text-black px-3 rounded-xl">
            {gettext("Manage less.")}
          </span>
        </h1>
        <p class="mt-7 text-lg md:text-xl text-white/70 max-w-2xl mx-auto leading-relaxed">
          {gettext(
            "Klass Hero is the operational backbone for Berlin's youth educators. We handle bookings, payments, and discovery — you focus on what you do best."
          )}
        </p>
        <div class="mt-10 flex gap-3 justify-center flex-wrap">
          <.kh_button variant={:primary} size={:lg} navigate={~p"/users/register"}>
            {gettext("Start teaching today")} →
          </.kh_button>
          <a href="#for-providers-pricing" class={ghost_dark_cta_classes()}>
            {gettext("See pricing")}
          </a>
        </div>
        <%!-- Hero stats strip omitted: FLAGS.md/Marketing/Hero/Trust-stat strip is ❌ (no real metrics source). --%>
      </div>
    </section>
    """
  end

  attr :benefits, :list, required: true

  defp benefits_section(assigns) do
    ~H"""
    <section id="for-providers-benefits" class="py-16 lg:py-24 bg-white">
      <div class="max-w-7xl mx-auto px-6">
        <div class="text-center max-w-2xl mx-auto mb-14">
          <.kh_pill tone={:primary} class="mb-3">{gettext("Why Klass Hero")}</.kh_pill>
          <h2 class={[Theme.typography(:page_title)]}>
            {gettext("Built for educators who want to teach, not run a business")}
          </h2>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <.kh_card :for={b <- @benefits} class="p-7 hover:shadow-lg hover:-translate-y-1">
            <.kh_icon_chip icon={b.icon} gradient={:primary} />
            <h3 class={["mt-5", Theme.typography(:card_title), "text-xl"]}>{b.title}</h3>
            <p class="mt-2 text-hero-grey-600 leading-relaxed">{b.desc}</p>
          </.kh_card>
        </div>
      </div>
    </section>
    """
  end

  attr :steps, :list, required: true

  defp how_it_works_section(assigns) do
    ~H"""
    <section
      id="for-providers-how-it-works"
      class="py-16 lg:py-24 bg-black text-white relative overflow-hidden"
    >
      <div class="absolute -top-20 -right-20 w-96 h-96 rounded-full bg-hero-blue-500 opacity-15 blur-3xl">
      </div>
      <div class="absolute -bottom-20 -left-20 w-96 h-96 rounded-full bg-hero-yellow-500 opacity-15 blur-3xl">
      </div>
      <div class="relative max-w-7xl mx-auto px-6">
        <div class="text-center max-w-2xl mx-auto mb-14">
          <.kh_pill tone={:accent} class="mb-3">{gettext("How it works")}</.kh_pill>
          <h2 class={[Theme.typography(:page_title), "text-white"]}>
            {gettext("From listing to first payout in under a week")}
          </h2>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div
            :for={s <- @steps}
            class="p-6 bg-white/5 backdrop-blur-sm rounded-2xl border border-white/10 hover:border-hero-yellow-500 transition-colors"
          >
            <div class="flex items-center justify-between mb-5">
              <%!-- typography-lint-ignore: numbered step badge in display font, intentional --%>
              <div class="w-12 h-12 rounded-xl bg-hero-yellow-500 text-black flex items-center justify-center font-display font-extrabold text-lg">
                {s.n}
              </div>
              <.icon name={s.icon} class="w-6 h-6 text-white/40" />
            </div>
            <h4 class="font-bold text-lg">{s.title}</h4>
            <p class="text-white/70 mt-2 leading-relaxed text-sm">{s.desc}</p>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :tiers, :list, required: true

  defp pricing_section(assigns) do
    ~H"""
    <section id="for-providers-pricing" class="py-16 lg:py-24 bg-hero-cream-100">
      <div class="max-w-7xl mx-auto px-6">
        <div class="text-center max-w-2xl mx-auto mb-10">
          <.kh_pill tone={:accent} class="mb-3">{gettext("Plans & Pricing")}</.kh_pill>
          <h2 class={[Theme.typography(:page_title)]}>
            {gettext("Pricing that grows with you")}
          </h2>
          <p class="text-hero-grey-600 text-lg mt-3">
            {gettext("Start free. Upgrade when it makes sense. No setup fees, cancel anytime.")}
          </p>
        </div>

        <%!-- Monthly/annual toggle omitted: FLAGS.md/Provider/Subscription/Monthly / annual toggle is ❌
              (only monthly prices exist in the entitlements config). --%>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div
            :for={tier <- @tiers}
            class={[
              "relative rounded-3xl p-7 transition-all",
              tier.popular &&
                "bg-black text-white shadow-2xl md:scale-[1.02]",
              !tier.popular &&
                "bg-white border border-hero-grey-200 hover:shadow-lg"
            ]}
          >
            <div
              :if={tier.popular}
              class="absolute -top-3 left-7 px-3 py-1 rounded-full bg-hero-yellow-500 text-black text-xs font-bold uppercase tracking-wide"
            >
              {gettext("Most popular")}
            </div>
            <h3 class={
              [
                # typography-lint-ignore: tier name uses display font as part of pricing card brand
                "font-display font-extrabold text-2xl",
                tier.popular && "text-hero-yellow-500"
              ]
            }>
              {tier.name}
            </h3>
            <p class={[
              "text-sm mt-1.5",
              if(tier.popular, do: "text-white/70", else: "text-hero-grey-600")
            ]}>
              {tier.blurb}
            </p>

            <div class="my-6">
              <div class="flex items-baseline gap-1.5">
                <%!-- typography-lint-ignore: pricing tier price uses display font for emphasis --%>
                <span class="font-display font-extrabold text-5xl">€{tier.monthly}</span>
                <span class={[
                  "text-sm font-semibold",
                  if(tier.popular, do: "text-white/60", else: "text-hero-grey-600")
                ]}>
                  /{gettext("mo")}
                </span>
              </div>
              <div class={[
                "text-xs mt-1.5 font-semibold",
                if(tier.popular, do: "text-white/60", else: "text-hero-grey-600")
              ]}>
                + {tier.listing_fee}
              </div>
            </div>

            <ul class="space-y-2.5 mb-7">
              <li :for={f <- tier.features} class="flex items-start gap-2 text-sm">
                <.icon
                  name="hero-check"
                  class={"w-4 h-4 mt-0.5 shrink-0 #{if tier.popular, do: "text-hero-yellow-500", else: "text-emerald-500"}"}
                />
                <span>{f}</span>
              </li>
            </ul>

            <.kh_button
              variant={if(tier.popular, do: :primary, else: :ghost)}
              size={:lg}
              navigate={~p"/users/register"}
              class="w-full justify-center"
            >
              <%= if tier.monthly == 0 do %>
                {gettext("Start for free")} →
              <% else %>
                {gettext("Choose")} {tier.name} →
              <% end %>
            </.kh_button>
          </div>
        </div>

        <p class="text-center text-sm text-hero-grey-600 mt-8">
          {gettext(
            "All plans include: secure payments · automatic invoicing · VAT handling · 24/7 support · the Klass Hero verified badge"
          )}
        </p>
      </div>
    </section>

    <%!-- Provider success stories section omitted:
          FLAGS.md/Marketing/For Providers page/Provider success stories is ❌
          (no review/case-study model; quotes & metrics would be mock). --%>
    """
  end

  attr :faqs, :list, required: true

  defp faq_section(assigns) do
    ~H"""
    <section id="for-providers-faq" class="py-16 lg:py-24 bg-white">
      <div class="max-w-3xl mx-auto px-6">
        <div class="text-center mb-10">
          <.kh_pill tone={:primary} class="mb-3">{gettext("FAQ")}</.kh_pill>
          <h2 class={[Theme.typography(:page_title)]}>
            {gettext("Provider questions, answered")}
          </h2>
        </div>
        <div class="space-y-3">
          <.faq_item
            :for={{f, idx} <- Enum.with_index(@faqs)}
            id={"for-providers-faq-#{idx}"}
            question={f.q}
            answer={f.a}
            expanded={idx == 0}
          />
        </div>
      </div>
    </section>
    """
  end

  ## ---------------------------------------------------------------------------
  ## Static data — mirrors design_handoff/marketing/Sections.jsx#MkForProviders
  ## ---------------------------------------------------------------------------

  # Bundle ships marketing tier names (Free/Studio/School) that map to the
  # backend atoms (:starter, :professional, :business_plus). When the
  # entitlements config adds a tier we should surface it here too — pulling
  # the keyword list from `Entitlements.all_provider_tiers/0` keeps the
  # contract honest even though prices/labels are display-only for now.
  defp ghost_dark_cta_classes do
    # typography-lint-ignore: ghost-on-dark CTA mirrors KhButton primary surface
    "inline-flex items-center justify-center gap-2 px-7 py-3.5 text-lg rounded-xl font-display font-bold tracking-tight border border-white/30 text-white hover:bg-white/10 transition-all"
  end

  defp pricing_tiers(provider_tiers) do
    backed_atoms = Keyword.keys(provider_tiers)

    [
      %{
        atom: :starter,
        name: gettext("Free"),
        blurb: gettext("Test the waters. List up to 2 programs, no monthly fee."),
        monthly: 0,
        listing_fee: gettext("15% per booking"),
        popular: false,
        features: [
          gettext("Up to 2 active programs"),
          gettext("Basic Klass Hero profile"),
          gettext("Direct messaging with parents"),
          gettext("Standard payment processing"),
          gettext("Email support")
        ]
      },
      %{
        atom: :professional,
        name: gettext("Studio"),
        blurb: gettext("For active educators running multiple programs."),
        monthly: 39,
        listing_fee: gettext("8% per booking"),
        popular: true,
        features: [
          gettext("Up to 10 programs"),
          gettext("Featured placement on home"),
          gettext("Custom branded profile"),
          gettext("Bulk parent broadcasts"),
          gettext("Calendar sync (iCal)"),
          gettext("Priority support")
        ]
      },
      %{
        atom: :business_plus,
        name: gettext("School"),
        blurb: gettext("For schools, academies, and multi-coach organizations."),
        monthly: 99,
        listing_fee: gettext("5% per booking"),
        popular: false,
        features: [
          gettext("Unlimited programs"),
          gettext("Multi-coach accounts (up to 8)"),
          gettext("Advanced analytics"),
          gettext("API access"),
          gettext("White-label invoices"),
          gettext("Dedicated CS contact")
        ]
      }
    ]
    |> Enum.filter(&(&1.atom in backed_atoms))
  end

  defp benefits do
    [
      %{
        icon: "hero-users",
        title: gettext("Stop chasing leads"),
        desc:
          gettext(
            "Berlin parents come to Klass Hero looking for trusted programs. You focus on teaching — we handle the funnel."
          )
      },
      %{
        icon: "hero-calendar",
        title: gettext("Less admin, more teaching"),
        desc:
          gettext("Bookings, rosters, schedules, attendance, parent comms — all in one place. No more spreadsheets.")
      },
      %{
        icon: "hero-currency-euro",
        title: gettext("Predictable income"),
        desc:
          gettext(
            "Weekly SEPA payouts, automatic VAT handling, transparent fees. Plan your business around real numbers."
          )
      },
      %{
        icon: "hero-shield-check",
        title: gettext("Built-in trust"),
        desc: gettext("The Klass Hero verified badge gets you more inquiries — parents trust vetted providers.")
      },
      %{
        icon: "hero-chat-bubble-left-right",
        title: gettext("Better parent relationships"),
        desc:
          gettext("Direct messaging, broadcast announcements, incident reports. Keep parents informed, automatically.")
      },
      %{
        icon: "hero-chart-bar",
        title: gettext("Insights that matter"),
        desc: gettext("Track signups, retention, no-shows, and revenue. Identify what's working and double down.")
      }
    ]
  end

  defp steps do
    [
      %{
        n: "01",
        icon: "hero-pencil",
        title: gettext("List your program"),
        desc: gettext("Build a listing in under 10 minutes. Schedule, capacity, photos, age range — done.")
      },
      %{
        n: "02",
        icon: "hero-shield-check",
        title: gettext("Get verified"),
        desc: gettext("Complete our 6-step Hero verification. We handle background checks, references and screening.")
      },
      %{
        n: "03",
        icon: "hero-users",
        title: gettext("Receive bookings"),
        desc: gettext("Parents discover you on Klass Hero. Approve manually or auto-accept — your call.")
      },
      %{
        n: "04",
        icon: "hero-currency-euro",
        title: gettext("Get paid weekly"),
        desc: gettext("Secure SEPA payouts every Monday. Refunds, invoices, and VAT handled automatically.")
      }
    ]
  end

  defp faqs do
    [
      %{
        q: gettext("How much does Klass Hero cost?"),
        a:
          gettext(
            "There's a free tier — list up to 2 programs at 15% per booking. The Studio plan is €39/mo with 8% per booking, and our School plan is €99/mo with 5% per booking. No setup fees, cancel anytime."
          )
      },
      %{
        q: gettext("How quickly can I start accepting bookings?"),
        a:
          gettext(
            "Once your listing is live and you've completed the 6-step verification (typically 3–5 business days), parents can book immediately. Most providers receive their first inquiry within the first week."
          )
      },
      %{
        q: gettext("How and when do I get paid?"),
        a:
          gettext(
            "We use SEPA bank transfers, paid out every Monday for the previous week's completed sessions. You'll receive an automatic invoice for each payout, and VAT is handled per-booking."
          )
      },
      %{
        q: gettext("What's the verification process like?"),
        a:
          gettext(
            "It's our 6-step Hero standard: identity & age verification, experience validation, extended police background check, video interview, child safeguarding training, and signing our community standards. See the Trust & Safety page for the full breakdown."
          )
      },
      %{
        q: gettext("Can I run programs at multiple locations?"),
        a:
          gettext(
            "Yes. The Studio plan supports multiple programs each with their own schedule and venue. The School plan adds multi-coach accounts so you can delegate management across instructors."
          )
      },
      %{
        q: gettext("What happens if a parent cancels?"),
        a:
          gettext(
            "Klass Hero handles refunds automatically based on your cancellation policy. You can choose flexible (free up to 48h before), moderate (free up to 7 days before), or strict (no refund) at the program level."
          )
      }
    ]
  end
end
