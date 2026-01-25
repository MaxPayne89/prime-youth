defmodule KlassHeroWeb.ProviderComponents do
  @moduledoc """
  UI components specific to the provider dashboard.
  """
  use Phoenix.Component
  use Gettext, backend: KlassHeroWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: KlassHeroWeb.Endpoint,
    router: KlassHeroWeb.Router,
    statics: KlassHeroWeb.static_paths()

  import KlassHeroWeb.UIComponents

  alias KlassHeroWeb.Theme

  @doc """
  Renders the provider dashboard tab navigation.

  ## Examples

      <.provider_nav_tabs live_action={@live_action} />
  """
  attr :live_action, :atom, required: true

  def provider_nav_tabs(assigns) do
    ~H"""
    <nav class="border-b border-hero-grey-200 mb-6">
      <div class="flex gap-1 overflow-x-auto pb-px -mb-px">
        <.nav_tab
          patch={~p"/provider/dashboard"}
          active={@live_action == :overview}
          icon="hero-squares-2x2-mini"
        >
          {gettext("Overview")}
        </.nav_tab>
        <.nav_tab
          patch={~p"/provider/dashboard/team"}
          active={@live_action == :team}
          icon="hero-user-group-mini"
        >
          {gettext("Team & Profiles")}
        </.nav_tab>
        <.nav_tab
          patch={~p"/provider/dashboard/programs"}
          active={@live_action == :programs}
          icon="hero-queue-list-mini"
        >
          {gettext("My Programs")}
        </.nav_tab>
      </div>
    </nav>
    """
  end

  attr :patch, :string, required: true
  attr :active, :boolean, required: true
  attr :icon, :string, required: true
  slot :inner_block, required: true

  defp nav_tab(assigns) do
    ~H"""
    <.link
      patch={@patch}
      class={[
        "flex items-center gap-2 px-4 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors",
        if(@active,
          do: "border-hero-cyan text-hero-cyan",
          else:
            "border-transparent text-hero-grey-500 hover:text-hero-grey-700 hover:border-hero-grey-300"
        )
      ]}
    >
      <.icon name={@icon} class="w-5 h-5" />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Renders a stat card for the provider dashboard.

  ## Examples

      <.provider_stat_card
        label="Total Revenue"
        value="12,500"
        icon="hero-currency-euro-mini"
        icon_bg="bg-hero-cyan-100"
        icon_color="text-hero-cyan"
      />
  """
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :icon, :string, required: true
  attr :icon_bg, :string, default: "bg-hero-cyan-100"
  attr :icon_color, :string, default: "text-hero-cyan"

  def provider_stat_card(assigns) do
    ~H"""
    <div class={[
      "bg-white p-4 shadow-sm border border-hero-grey-200",
      Theme.rounded(:xl)
    ]}>
      <div class="flex items-center gap-3">
        <div class={["w-10 h-10 flex items-center justify-center", Theme.rounded(:lg), @icon_bg]}>
          <.icon name={@icon} class={"w-5 h-5 #{@icon_color}"} />
        </div>
        <div>
          <p class="text-sm text-hero-grey-500">{@label}</p>
          <p class="text-2xl font-bold text-hero-charcoal">{@value}</p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders the business profile card with verification badges.

  ## Examples

      <.business_profile_card business={@business} />
  """
  attr :business, :map, required: true

  def business_profile_card(assigns) do
    ~H"""
    <div class={["bg-white p-6 shadow-sm border border-hero-grey-200", Theme.rounded(:xl)]}>
      <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4 mb-4">
        <div>
          <h2 class="text-xl font-semibold text-hero-charcoal mb-1">
            {gettext("Business Profile")}
          </h2>
          <p class="text-sm text-hero-grey-500">
            {gettext(
              "This is your main business identity. Verification is required to list programs."
            )}
          </p>
        </div>
        <button
          type="button"
          class={[
            "flex items-center gap-2 px-4 py-2 border border-hero-grey-300 bg-white",
            "hover:bg-hero-grey-50 text-hero-charcoal text-sm font-medium",
            Theme.rounded(:lg),
            Theme.transition(:normal)
          ]}
        >
          <.icon name="hero-pencil-square-mini" class="w-4 h-4" />
          {gettext("Edit Profile")}
        </button>
      </div>

      <div class="flex items-center gap-4">
        <div class={[
          "w-20 h-20 flex items-center justify-center text-white text-2xl font-bold",
          Theme.rounded(:full),
          Theme.gradient(:primary)
        ]}>
          {@business.initials}
        </div>
        <div>
          <h3 class="text-xl font-semibold text-hero-charcoal">{@business.name}</h3>
          <p class="text-hero-grey-500 mb-2">{@business.tagline}</p>
          <div class="flex flex-wrap gap-2">
            <.verification_badge
              :for={badge <- @business.verification_badges}
              icon={badge_icon(badge.key)}
              label={badge.label}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp badge_icon(:business_registration), do: "hero-check-badge-mini"
  defp badge_icon(:insurance), do: "hero-shield-check-mini"
  defp badge_icon(_), do: "hero-check-mini"

  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp verification_badge(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-1.5 px-3 py-1.5 bg-hero-grey-100 text-hero-grey-700 text-xs font-medium",
      Theme.rounded(:full)
    ]}>
      <.icon name={@icon} class="w-4 h-4 text-green-600" />
      <span class="uppercase tracking-wide">{@label}</span>
    </div>
    """
  end

  @doc """
  Renders the dashboard header with business name and badges.

  ## Examples

      <.provider_dashboard_header business={@business} />
  """
  attr :business, :map, required: true

  def provider_dashboard_header(assigns) do
    ~H"""
    <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4 mb-6">
      <div>
        <h1 class="text-2xl font-bold text-hero-charcoal mb-2">
          {@business.name} {gettext("Dashboard")}
        </h1>
        <div class="flex flex-wrap items-center gap-2">
          <span class={[
            "px-3 py-1 text-xs font-semibold text-white uppercase tracking-wide",
            Theme.rounded(:full),
            "bg-green-500"
          ]}>
            {@business.plan_label}
          </span>
          <span
            :if={@business.verified}
            class={[
              "flex items-center gap-1 px-3 py-1 text-xs font-medium border border-green-500 text-green-600",
              Theme.rounded(:full)
            ]}
          >
            <.icon name="hero-check-badge-mini" class="w-4 h-4" />
            {gettext("Verified Business")}
          </span>
        </div>
      </div>

      <div class="flex items-center gap-4">
        <div class="text-right">
          <p class="text-xs text-hero-grey-500 uppercase tracking-wide">
            {gettext("Program Slots")}
          </p>
          <p class="text-lg font-semibold text-hero-charcoal">
            {@business.program_slots_used}/{if @business.program_slots_total,
              do: @business.program_slots_total,
              else: "∞"}
          </p>
        </div>
        <button
          type="button"
          class={[
            "flex items-center gap-2 px-4 py-2 bg-hero-yellow hover:bg-hero-yellow-dark",
            "text-hero-charcoal font-semibold",
            Theme.rounded(:lg),
            Theme.transition(:normal)
          ]}
        >
          <.icon name="hero-plus-mini" class="w-5 h-5" />
          {gettext("New Program")}
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a team member card.

  ## Examples

      <.team_member_card member={member} />
  """
  attr :member, :map, required: true

  def team_member_card(assigns) do
    ~H"""
    <div class={["bg-white shadow-sm border border-hero-grey-200 overflow-hidden", Theme.rounded(:xl)]}>
      <div class="relative h-24 bg-gradient-to-r from-hero-grey-200 to-hero-grey-300">
        <div class={[
          "absolute top-2 right-2 px-2 py-1 bg-white/90 text-xs font-medium text-hero-charcoal",
          Theme.rounded(:md)
        ]}>
          {@member.role}
        </div>
        <div class={[
          "absolute -bottom-8 left-4 w-16 h-16 flex items-center justify-center",
          "text-white text-xl font-bold border-4 border-white",
          Theme.rounded(:full),
          Theme.gradient(:primary)
        ]}>
          {@member.initials}
        </div>
      </div>

      <div class="pt-10 px-4 pb-4">
        <h3 class="font-semibold text-hero-charcoal">{@member.name}</h3>
        <p class="text-sm text-hero-grey-500 mb-2">{@member.email}</p>
        <p class="text-sm text-hero-grey-600 mb-3 line-clamp-2">{@member.bio}</p>

        <div class="flex flex-wrap gap-1.5 mb-3">
          <span
            :for={cert <- @member.certifications}
            class={[
              "px-2 py-1 text-xs font-medium border border-hero-grey-300 text-hero-grey-600",
              Theme.rounded(:md)
            ]}
          >
            {cert}
          </span>
        </div>

        <div class="flex items-center gap-1 text-sm text-hero-grey-500 mb-4">
          <.icon name="hero-currency-euro-mini" class="w-4 h-4" />
          <span>{gettext("Rate")}: €{@member.hourly_rate}/hr</span>
        </div>

        <div class="flex items-center gap-2">
          <button
            type="button"
            class={[
              "flex-1 px-4 py-2 border border-hero-grey-300 bg-white",
              "hover:bg-hero-grey-50 text-hero-charcoal text-sm font-medium",
              Theme.rounded(:lg),
              Theme.transition(:normal)
            ]}
          >
            {gettext("Edit")}
          </button>
          <button
            type="button"
            class={[
              "p-2 text-red-500 hover:bg-red-50",
              Theme.rounded(:lg),
              Theme.transition(:normal)
            ]}
          >
            <.icon name="hero-x-mark-mini" class="w-5 h-5" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders an "Add" card with dashed border.

  ## Examples

      <.add_card_button label="Add Team Member" icon="hero-user-plus-mini" />
  """
  attr :label, :string, required: true
  attr :icon, :string, default: "hero-plus-mini"
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click)

  def add_card_button(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "w-full h-full min-h-[200px] border-2 border-dashed border-hero-grey-300",
        "flex flex-col items-center justify-center gap-2",
        "text-hero-grey-400 hover:border-hero-cyan hover:text-hero-cyan",
        Theme.rounded(:xl),
        Theme.transition(:normal),
        @class
      ]}
      {@rest}
    >
      <.icon name={@icon} class="w-8 h-8" />
      <span class="font-medium">{@label}</span>
    </button>
    """
  end

  @doc """
  Renders the programs table with search and filters.

  ## Examples

      <.programs_table
        programs={@programs}
        staff_options={@staff_options}
        search_query=""
        selected_staff="all"
      />
  """
  attr :programs, :any, required: true, doc: "LiveView stream of programs"
  attr :staff_options, :list, required: true
  attr :search_query, :string, default: ""
  attr :selected_staff, :string, default: "all"

  def programs_table(assigns) do
    ~H"""
    <div class={["bg-white shadow-sm border border-hero-grey-200", Theme.rounded(:xl)]}>
      <div class="p-4 border-b border-hero-grey-200">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <h3 class="text-lg font-semibold text-hero-charcoal">
            {gettext("Program Inventory")}
          </h3>
          <div class="flex flex-col sm:flex-row gap-2">
            <div class="relative">
              <.icon
                name="hero-magnifying-glass-mini"
                class="w-5 h-5 text-hero-grey-400 absolute left-3 top-1/2 -translate-y-1/2"
              />
              <input
                type="text"
                name="search"
                value={@search_query}
                placeholder={gettext("Search by name...")}
                class={[
                  "pl-10 pr-4 py-2 w-full sm:w-64 border border-hero-grey-300 bg-white",
                  "text-sm placeholder-hero-grey-400 focus:border-hero-cyan focus:ring-1 focus:ring-hero-cyan",
                  Theme.rounded(:lg)
                ]}
                phx-change="search_programs"
                phx-debounce="300"
              />
            </div>
            <div class="relative">
              <.icon
                name="hero-funnel-mini"
                class="w-5 h-5 text-hero-grey-400 absolute left-3 top-1/2 -translate-y-1/2"
              />
              <select
                name="staff_filter"
                class={[
                  "pl-10 pr-8 py-2 w-full sm:w-40 border border-hero-grey-300 bg-white",
                  "text-sm focus:border-hero-cyan focus:ring-1 focus:ring-hero-cyan appearance-none",
                  Theme.rounded(:lg)
                ]}
                phx-change="filter_by_staff"
              >
                <option
                  :for={option <- @staff_options}
                  value={option.value}
                  selected={option.value == @selected_staff}
                >
                  {option.label}
                </option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <div class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-hero-grey-50 border-b border-hero-grey-200">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-semibold text-hero-grey-500 uppercase tracking-wider">
                {gettext("Program Name")}
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-hero-grey-500 uppercase tracking-wider">
                {gettext("Assigned Staff")}
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-hero-grey-500 uppercase tracking-wider">
                {gettext("Status")}
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-hero-grey-500 uppercase tracking-wider">
                {gettext("Enrollment")}
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold text-hero-grey-500 uppercase tracking-wider">
                {gettext("Actions")}
              </th>
            </tr>
          </thead>
          <tbody id="programs-table-body" phx-update="stream" class="divide-y divide-hero-grey-200">
            <tr :for={{dom_id, program} <- @programs} id={dom_id} class="hover:bg-hero-grey-50">
              <td class="px-4 py-4">
                <div class="font-medium text-hero-charcoal">{program.name}</div>
                <div class="text-sm text-hero-grey-500">
                  {program.category} • €{program.price}
                </div>
              </td>
              <td class="px-4 py-4">
                <div :if={program.assigned_staff} class="flex items-center gap-2">
                  <div class={[
                    "w-8 h-8 flex items-center justify-center text-white text-xs font-medium",
                    Theme.rounded(:full),
                    Theme.gradient(:primary)
                  ]}>
                    {program.assigned_staff.initials}
                  </div>
                  <span class="text-sm text-hero-charcoal">{program.assigned_staff.name}</span>
                </div>
                <span :if={!program.assigned_staff} class="text-sm text-hero-grey-400 italic">
                  {gettext("Unassigned")}
                </span>
              </td>
              <td class="px-4 py-4">
                <.status_pill color={status_color(program.status)}>
                  {status_label(program.status)}
                </.status_pill>
              </td>
              <td class="px-4 py-4">
                <div class="flex items-center gap-3">
                  <div class="w-24 h-2 bg-hero-grey-200 rounded-full overflow-hidden">
                    <div
                      class="h-full bg-hero-cyan rounded-full"
                      style={"width: #{enrollment_percentage(program)}%"}
                    >
                    </div>
                  </div>
                  <span class="text-sm text-hero-grey-600">
                    {program.enrolled}/{program.capacity}
                  </span>
                </div>
              </td>
              <td class="px-4 py-4">
                <div class="flex items-center justify-end gap-1">
                  <.action_button icon="hero-eye-mini" title={gettext("Preview")} />
                  <.action_button icon="hero-user-group-mini" title={gettext("View Roster")} />
                  <.action_button icon="hero-pencil-square-mini" title={gettext("Edit")} />
                  <.action_button icon="hero-document-duplicate-mini" title={gettext("Duplicate")} />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp status_color(:active), do: "success"
  defp status_color(:pending), do: "warning"
  defp status_color(:inactive), do: "error"
  defp status_color(_), do: "info"

  defp status_label(:active), do: gettext("Active")
  defp status_label(:pending), do: gettext("Pending")
  defp status_label(:inactive), do: gettext("Inactive")
  defp status_label(_), do: gettext("Unknown")

  defp enrollment_percentage(program) do
    if program.capacity > 0 do
      min(100, div(program.enrolled * 100, program.capacity))
    else
      0
    end
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :rest, :global, include: ~w(phx-click phx-value-id)

  defp action_button(assigns) do
    ~H"""
    <button
      type="button"
      title={@title}
      class={[
        "p-2 text-hero-grey-400 hover:text-hero-charcoal hover:bg-hero-grey-100",
        Theme.rounded(:lg),
        Theme.transition(:normal)
      ]}
      {@rest}
    >
      <.icon name={@icon} class="w-5 h-5" />
    </button>
    """
  end
end
