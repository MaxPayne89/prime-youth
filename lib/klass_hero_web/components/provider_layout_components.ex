defmodule KlassHeroWeb.ProviderLayoutComponents do
  @moduledoc """
  Function components for the authenticated provider surface.

  Mirrors the `Pv*` primitives in `design_handoff/provider_app/Sections.jsx`.
  Held separate from the existing `provider_components.ex` (which is large
  and domain-specific) so the layout vocabulary can evolve independently.

  Sidebar is BLACK with a yellow active accent — intentional contrast with
  the parent surface's white-with-blue sidebar.
  """

  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: KlassHeroWeb.Endpoint,
    router: KlassHeroWeb.Router,
    statics: KlassHeroWeb.static_paths()

  use Gettext, backend: KlassHeroWeb.Gettext

  import KlassHeroWeb.UIComponents,
    only: [kh_logo: 1, kh_card: 1, kh_pill: 1, kh_icon_chip: 1, kh_list_row: 1]

  @desktop_items [
    {:home, "Overview", "hero-home", "/provider/dashboard"},
    {:programs, "Programs", "hero-book-open", "/provider/dashboard/programs"},
    {:roster, "Sessions", "hero-users", "/provider/sessions"},
    {:calendar, "Schedule", "hero-calendar", nil},
    {:messages, "Comms", "hero-inbox", "/provider/messages"},
    {:settings, "Settings", "hero-cog-6-tooth", "/provider/complete-profile"}
  ]

  @mobile_tabs [
    {:home, "Overview", "hero-home", "/provider/dashboard"},
    {:roster, "Sessions", "hero-users", "/provider/sessions"},
    {:messages, "Comms", "hero-inbox", "/provider/messages"},
    {:settings, "Settings", "hero-cog-6-tooth", "/provider/complete-profile"}
  ]

  @doc """
  Provider sidebar (desktop) + bottom-tab nav (mobile).
  """
  attr :active, :atom,
    required: true,
    values: [:home, :programs, :roster, :calendar, :messages, :settings]

  def pv_sidebar(assigns) do
    assigns = assign(assigns, items: @desktop_items, tabs: @mobile_tabs)

    ~H"""
    <aside class="hidden lg:flex w-[220px] shrink-0 h-screen sticky top-0 bg-black text-white flex-col">
      <div class="p-5 border-b border-white/10">
        <.link navigate={~p"/"} class="flex items-center" aria-label="Klass Hero">
          <.kh_logo size={28} />
        </.link>
        <div class="text-[11px] text-white/60 uppercase tracking-wider font-bold mt-3">
          {gettext("Provider")}
        </div>
      </div>
      <nav class="p-3 flex-1" aria-label={gettext("Provider navigation")}>
        <.pv_sidebar_link
          :for={{key, label, icon, href} <- @items}
          key={key}
          label={label}
          icon={icon}
          href={href}
          active?={@active == key}
        />
      </nav>
      <div class="p-4 border-t border-white/10">
        <div class="p-3 rounded-xl bg-white/5">
          <div class="flex items-center gap-2 text-xs text-white/70">
            <.icon name="hero-sparkles" class="w-3.5 h-3.5" /> {gettext("Pro tip")}
          </div>
          <p class="mt-1 text-xs text-white/90 leading-relaxed">
            {gettext("Add 3+ photos to boost bookings by ~40%.")}
          </p>
          <a
            href="/provider/subscription"
            class="mt-2 block text-[11px] font-bold text-[var(--brand-primary)] hover:underline"
          >
            {gettext("View subscription")} →
          </a>
        </div>
      </div>
    </aside>

    <nav
      class="lg:hidden fixed bottom-0 left-0 right-0 z-40 bg-black flex items-stretch h-[64px] pb-[env(safe-area-inset-bottom)] shadow-[0_-4px_16px_rgba(0,0,0,.18)]"
      aria-label={gettext("Provider bottom navigation")}
    >
      <.pv_bottom_tab
        :for={{key, label, icon, href} <- @tabs}
        key={key}
        label={label}
        icon={icon}
        href={href}
        active?={@active == key}
      />
    </nav>
    """
  end

  attr :key, :atom, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :href, :string, default: nil
  attr :active?, :boolean, default: false

  defp pv_sidebar_link(assigns) do
    ~H"""
    <a
      :if={@href}
      href={@href}
      class={[
        "flex items-center gap-3 px-3 py-2.5 rounded-xl mb-1 transition-all font-semibold text-sm no-underline",
        @active? && "bg-[var(--hero-yellow-500)] text-black",
        !@active? && "text-white/70 hover:bg-white/10 hover:text-white"
      ]}
      aria-current={@active? && "page"}
    >
      <.icon name={@icon} class="w-5 h-5" /> {@label}
    </a>
    <span
      :if={!@href}
      class="flex items-center gap-3 px-3 py-2.5 rounded-xl mb-1 font-semibold text-sm text-white/40 cursor-not-allowed"
      title={gettext("Coming soon")}
    >
      <.icon name={@icon} class="w-5 h-5 opacity-60" /> {@label}
    </span>
    """
  end

  attr :key, :atom, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :href, :string, default: nil
  attr :active?, :boolean, default: false

  defp pv_bottom_tab(assigns) do
    ~H"""
    <a
      :if={@href}
      href={@href}
      aria-current={@active? && "page"}
      class={[
        "relative flex-1 flex flex-col items-center justify-center gap-1 no-underline transition-colors",
        @active? && "text-[var(--hero-yellow-500)]",
        !@active? && "text-white/60 hover:text-white"
      ]}
    >
      <span
        :if={@active?}
        class="absolute top-0 w-10 h-[3px] rounded-b-full bg-[var(--hero-yellow-500)]"
        aria-hidden="true"
      >
      </span>
      <.icon name={@icon} class="w-6 h-6" />
      <span class={[
        "text-[10px] tracking-tight",
        if(@active?, do: "font-bold", else: "font-semibold")
      ]}>
        {@label}
      </span>
    </a>
    """
  end

  @doc """
  Provider topbar with provider identity, verified pill, and trailing CTAs.

  `provider` shape: `%{name, tagline, verified?: boolean}`. Mobile shrinks
  to a sticky compact header.
  """
  attr :provider, :map, required: true
  attr :show_new_program_cta, :boolean, default: false

  slot :extra_actions

  def pv_topbar(assigns) do
    ~H"""
    <div class="hidden lg:flex px-8 py-6 bg-white border-b border-hero-grey-200 items-center justify-between">
      <div class="flex items-center gap-4">
        <div class={pv_topbar_avatar_desktop_classes()}>
          {String.first(@provider[:name] || "?") |> String.upcase()}
        </div>
        <div>
          <div class="flex items-center gap-2">
            <h1 class={pv_topbar_title_classes()}>{@provider[:name]}</h1>
            <.kh_pill :if={@provider[:verified?]} tone={:success}>
              <.icon name="hero-shield-check" class="w-3 h-3" /> {gettext("Verified")}
            </.kh_pill>
          </div>
          <div :if={@provider[:tagline]} class="text-sm text-hero-grey-600 mt-0.5">
            {@provider.tagline}
          </div>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <a
          href="/provider/dashboard"
          class={pv_topbar_ghost_button_classes()}
        >
          <.icon name="hero-eye" class="w-4 h-4" /> {gettext("Preview public page")}
        </a>
        {render_slot(@extra_actions)}
        <a
          :if={@show_new_program_cta}
          href="/provider/dashboard/edit"
          class={pv_topbar_primary_button_classes()}
        >
          <.icon name="hero-plus" class="w-4 h-4" /> {gettext("New program")}
        </a>
      </div>
    </div>

    <div class="lg:hidden sticky top-0 z-30 bg-white/95 backdrop-blur-sm border-b border-hero-grey-200 px-4 h-14 flex items-center gap-3">
      <.link navigate={~p"/"} class="flex items-center shrink-0" aria-label="Klass Hero">
        <.kh_logo size={26} />
      </.link>
      <div class={pv_topbar_avatar_mobile_classes()}>
        {String.first(@provider[:name] || "?") |> String.upcase()}
      </div>
      <div class="flex-1 min-w-0 flex items-center gap-1.5">
        <h1 class={pv_topbar_mobile_title_classes()}>{@provider[:name]}</h1>
        <.icon
          :if={@provider[:verified?]}
          name="hero-shield-check"
          class="w-3.5 h-3.5 text-emerald-500 shrink-0"
        />
      </div>
      <a
        href="/provider/dashboard"
        aria-label={gettext("Preview public page")}
        class="w-9 h-9 rounded-full bg-hero-cream-100 flex items-center justify-center hover:bg-hero-pink-50 shrink-0"
      >
        <.icon name="hero-eye" class="w-[18px] h-[18px]" />
      </a>
    </div>
    """
  end

  @doc """
  Provider stat card. Maps to bundle's `PvStatCard` (Sections.jsx:115).

  `trend` is an optional integer percentage delta — if `nil`, the up/down
  arrow is hidden. Per Q3.4 the dashboard ships with `trend=nil` until
  historical comparison queries land.
  """
  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :caption, :string, default: nil
  attr :icon, :string, required: true
  attr :tone, :atom, default: :primary
  attr :trend, :integer, default: nil
  attr :disabled, :boolean, default: false

  def pv_stat_card(assigns) do
    ~H"""
    <.kh_card class={"p-5 #{if @disabled, do: "opacity-60", else: ""}"}>
      <div class="flex items-center justify-between mb-3">
        <.kh_icon_chip icon={@icon} gradient={@tone} size={:sm} />
        <span
          :if={@trend}
          class={[
            "text-xs font-bold",
            if(@trend > 0, do: "text-emerald-600", else: "text-red-500")
          ]}
        >
          {if @trend > 0, do: "↑", else: "↓"} {abs(@trend)}%
        </span>
      </div>
      <div class={pv_stat_value_classes()}>{@value}</div>
      <div class="mt-1 text-[13px] text-hero-grey-600 font-semibold">{@title}</div>
      <div :if={@caption} class="text-xs text-hero-grey-600 mt-1">{@caption}</div>
    </.kh_card>
    """
  end

  @doc """
  Earnings chart placeholder.

  `data` is a list of `%{w: "W1", v: 1200}` maps. When the list is empty,
  renders an explainer card pointing at #178 (Stripe transactions).
  """
  attr :data, :list, default: []

  def pv_earnings_chart(assigns) do
    ~H"""
    <.kh_card class="p-6">
      <div class="flex items-center justify-between mb-5">
        <div>
          <h3 class="font-bold text-lg">{gettext("Earnings trend")}</h3>
          <div class="text-sm text-hero-grey-600">{gettext("Last 8 weeks")}</div>
        </div>
        <div class="flex gap-2">
          <.kh_pill tone={:dark}>{gettext("Week")}</.kh_pill>
          <.kh_pill tone={:outline}>{gettext("Month")}</.kh_pill>
          <.kh_pill tone={:outline}>{gettext("Year")}</.kh_pill>
        </div>
      </div>
      <div :if={@data == []} class="py-12 text-center text-sm text-hero-grey-600">
        {gettext("Earnings data lights up once Stripe transactions ship (#178).")}
      </div>
      <div :if={@data != []} class="flex items-end gap-2 h-40 px-1">
        <.pv_chart_bar :for={d <- @data} datum={d} max={chart_max(@data)} />
      </div>
    </.kh_card>
    """
  end

  attr :datum, :map, required: true
  attr :max, :integer, required: true

  defp pv_chart_bar(assigns) do
    height = round(assigns.datum.v / max(assigns.max, 1) * 100)
    assigns = assign(assigns, height: height)

    ~H"""
    <div class="flex-1 flex flex-col items-center gap-2 group">
      <div
        class="w-full rounded-t-lg bg-gradient-to-t from-hero-blue-500 to-hero-blue-300 transition-all hover:from-hero-yellow-500 hover:to-hero-yellow-300 relative"
        style={"height: #{@height}%"}
      >
        <div class="absolute -top-7 left-1/2 -translate-x-1/2 bg-black text-white px-2 py-0.5 rounded text-[10px] font-bold opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap">
          €{@datum.v}
        </div>
      </div>
      <div class="text-[10px] text-hero-grey-600 font-semibold">{@datum.w}</div>
    </div>
    """
  end

  defp chart_max(data), do: data |> Enum.map(& &1.v) |> Enum.max(fn -> 1 end)

  @doc """
  Compact program-row primitive used by dashboard + sessions screens.
  """
  attr :program, :map, required: true
  attr :on_edit, :string, default: "edit_program"

  def pv_program_row(assigns) do
    ~H"""
    <.kh_list_row hover>
      <:media>
        <div
          class="w-14 h-14 rounded-xl"
          style={"background: #{@program[:cover] || "linear-gradient(135deg,#33CFFF,#FFFF36)"}"}
        >
        </div>
      </:media>
      <:title>{@program.title}</:title>
      <:pill :if={@program[:status]}>
        <.kh_pill tone={status_tone(@program.status)}>{to_string(@program.status)}</.kh_pill>
      </:pill>
      <:actions>
        <button
          type="button"
          phx-click={@on_edit}
          phx-value-program-id={@program[:id]}
          aria-label={gettext("Edit program")}
          class="w-9 h-9 rounded-lg bg-white border border-hero-grey-200 flex items-center justify-center hover:bg-[var(--brand-primary)] hover:border-transparent"
        >
          <.icon name="hero-pencil" class="w-4 h-4" />
        </button>
      </:actions>
    </.kh_list_row>
    """
  end

  defp status_tone(:live), do: :success
  defp status_tone(:draft), do: :cream
  defp status_tone(:full), do: :error
  defp status_tone(_), do: :warning

  @doc """
  Today's session roster card with check-in toggles.

  `kids` is a list of `%{id, name, parent, present?: boolean, color}` maps.
  """
  attr :session, :map, required: true
  attr :kids, :list, required: true
  attr :on_check_in, :string, default: "check_in"
  attr :on_mark_all_present, :string, default: "mark_all_present"

  def pv_roster(assigns) do
    ~H"""
    <.kh_card class="p-5">
      <div class="flex items-center justify-between mb-4">
        <div>
          <h3 class="font-bold text-lg">{gettext("Today's check-ins")}</h3>
          <div :if={@session[:subtitle]} class="text-sm text-hero-grey-600">
            {@session.subtitle}
          </div>
        </div>
        <button
          type="button"
          phx-click={@on_mark_all_present}
          class="px-3 py-1.5 text-xs font-bold rounded-lg border border-hero-grey-300 hover:bg-hero-cream-100"
        >
          {gettext("Mark all present")}
        </button>
      </div>
      <div :if={@kids == []} class="text-sm text-hero-grey-600">
        {gettext("No registered children for this session.")}
      </div>
      <div class="space-y-1">
        <.kh_list_row
          :for={k <- @kids}
          density={:compact}
          hover
          meta={gettext("Parent: %{name}", name: k[:parent] || "—")}
        >
          <:media>
            <div
              class="w-9 h-9 rounded-full flex items-center justify-center font-bold text-black text-sm"
              style={"background: #{k[:color] || "#FFEAC9"}"}
            >
              {String.first(k.name || "?") |> String.upcase()}
            </div>
          </:media>
          <:title>{k.name}</:title>
          <:actions>
            <button
              type="button"
              phx-click={@on_check_in}
              phx-value-kid-id={k.id}
              aria-label={if k[:present?], do: gettext("Mark absent"), else: gettext("Mark present")}
              class={[
                "w-7 h-7 rounded-full flex items-center justify-center transition-all",
                k[:present?] && "bg-emerald-500 text-white",
                !k[:present?] &&
                  "bg-hero-grey-100 text-hero-grey-600 hover:bg-[var(--brand-primary)] hover:text-black"
              ]}
            >
              <.icon name="hero-check-circle" class="w-4 h-4" />
            </button>
          </:actions>
        </.kh_list_row>
      </div>
    </.kh_card>
    """
  end

  @doc """
  Pending booking-request card with Accept / Decline footer actions.

  `request` keys: `:id, :parent, :program, :child, :when, :color`.
  """
  attr :request, :map, required: true
  attr :on_accept, :string, default: "accept_request"
  attr :on_decline, :string, default: "decline_request"

  def pv_request_card(assigns) do
    ~H"""
    <.kh_list_row
      class="border border-hero-grey-200 bg-white"
      meta={[@request[:program], @request[:child]]}
    >
      <:media>
        <div
          class="w-9 h-9 rounded-full flex items-center justify-center font-bold text-black text-sm"
          style={"background: #{@request[:color] || "#FFEAC9"}"}
        >
          {String.first(@request[:parent] || "?") |> String.upcase()}
        </div>
      </:media>
      <:title>{@request[:parent] || gettext("Unknown parent")}</:title>
      <:footer>
        <div class="flex gap-2 justify-end">
          <button
            type="button"
            phx-click={@on_decline}
            phx-value-request-id={@request[:id]}
            class="px-3 py-1.5 text-xs font-bold rounded-lg border border-hero-grey-300 hover:bg-hero-grey-100"
          >
            {gettext("Decline")}
          </button>
          <button
            type="button"
            phx-click={@on_accept}
            phx-value-request-id={@request[:id]}
            class="px-3 py-1.5 text-xs font-bold rounded-lg bg-[var(--brand-primary)] text-black hover:shadow-md"
          >
            {gettext("Accept")}
          </button>
        </div>
      </:footer>
    </.kh_list_row>
    """
  end

  ## ---------------------------------------------------------------------------
  ## Internal helpers
  ## ---------------------------------------------------------------------------

  attr :name, :string, required: true
  attr :class, :string, default: "w-5 h-5"
  defp icon(assigns), do: KlassHeroWeb.UIComponents.icon(assigns)

  # typography-lint-ignore: PvTopbar provider name uses display font
  defp pv_topbar_title_classes, do: "font-display font-extrabold tracking-tight text-2xl"

  defp pv_topbar_mobile_title_classes do
    # typography-lint-ignore: mobile compact provider name
    "font-display font-extrabold tracking-tight text-[15px] leading-none truncate"
  end

  defp pv_topbar_avatar_desktop_classes do
    # typography-lint-ignore: PvTopbar desktop avatar initial uses display font
    "w-14 h-14 rounded-2xl bg-gradient-to-br from-hero-blue-400 to-hero-yellow-500 flex items-center justify-center font-display font-extrabold text-2xl"
  end

  defp pv_topbar_avatar_mobile_classes do
    # typography-lint-ignore: PvTopbar mobile avatar initial uses display font
    "w-8 h-8 rounded-lg bg-gradient-to-br from-hero-blue-400 to-hero-yellow-500 flex items-center justify-center font-display font-extrabold text-sm shrink-0"
  end

  defp pv_topbar_ghost_button_classes do
    # typography-lint-ignore: ghost CTA mirrors KhButton ghost variant
    "inline-flex items-center justify-center gap-2 px-3.5 py-2 text-sm rounded-lg font-display font-bold tracking-tight bg-transparent text-hero-black-100 border border-hero-grey-300 hover:bg-hero-grey-100"
  end

  defp pv_topbar_primary_button_classes do
    # typography-lint-ignore: primary CTA mirrors KhButton primary surface
    "inline-flex items-center justify-center gap-2 px-3.5 py-2 text-sm rounded-lg font-display font-bold tracking-tight bg-[var(--brand-primary)] hover:bg-[var(--brand-primary-hover)] text-black"
  end

  defp pv_stat_value_classes do
    # typography-lint-ignore: PvStatCard value is numeric callout
    "font-display font-extrabold text-3xl tracking-tight"
  end
end
