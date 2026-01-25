defmodule KlassHeroWeb.Provider.DashboardLive do
  @moduledoc """
  Provider dashboard LiveView with tab-based navigation.

  Sections:
  - Overview: Stats, business profile, verification badges
  - Team & Profiles: Team member management
  - My Programs: Program inventory and management
  """
  use KlassHeroWeb, :live_view

  import KlassHeroWeb.ProviderComponents

  alias KlassHero.Entitlements
  alias KlassHero.ProgramCatalog
  alias KlassHeroWeb.Provider.MockData
  alias KlassHeroWeb.Theme

  @impl true
  def mount(_params, _session, socket) do
    provider_profile = socket.assigns.current_scope.provider
    business = build_business_from_provider(provider_profile)

    # Load real programs for this provider
    domain_programs = ProgramCatalog.list_programs_for_provider(provider_profile.id)
    programs = Enum.map(domain_programs, &map_program_to_ui/1)

    # Update business with actual program count
    business = %{business | program_slots_used: length(programs)}

    # Mock data for stats/team until features are implemented
    stats = MockData.stats()
    team = MockData.team()
    staff_options = MockData.staff_options()

    socket =
      socket
      |> assign(page_title: gettext("Provider Dashboard"))
      |> assign(business: business)
      |> assign(stats: stats)
      |> assign(team: team)
      |> assign(programs: programs)
      |> assign(staff_options: staff_options)
      |> assign(search_query: "")
      |> assign(selected_staff: "all")

    {:ok, socket}
  end

  defp map_program_to_ui(program) do
    %{
      id: program.id,
      name: program.title,
      category: humanize_category(program.category),
      price: Decimal.to_integer(program.price),
      assigned_staff: nil,
      status: :active,
      enrolled: 0,
      capacity: program.spots_available
    }
  end

  defp humanize_category(nil), do: "General"
  defp humanize_category("arts"), do: gettext("Arts")
  defp humanize_category("education"), do: gettext("Education")
  defp humanize_category("sports"), do: gettext("Sports")
  defp humanize_category("music"), do: gettext("Music")
  defp humanize_category(category), do: String.capitalize(category)

  defp build_business_from_provider(provider) do
    tier = provider.subscription_tier || :starter
    tier_info = Entitlements.provider_tier_info(tier)

    %{
      id: provider.id,
      name: provider.business_name,
      tagline: provider.description,
      plan: tier,
      plan_label: tier_label(tier),
      verified: provider.verified || false,
      verification_badges: build_verification_badges(provider),
      program_slots_used: 0,
      program_slots_total: tier_info[:max_programs],
      initials: build_initials(provider.business_name)
    }
  end

  defp tier_label(:starter), do: gettext("Starter Plan")
  defp tier_label(:professional), do: gettext("Professional Plan")
  defp tier_label(:business_plus), do: gettext("Business Plus Plan")
  defp tier_label(_), do: gettext("Starter Plan")

  defp build_verification_badges(%{verified: true}) do
    [
      %{key: :business_registration, label: gettext("Business Registration")}
    ]
  end

  defp build_verification_badges(_), do: []

  defp build_initials(nil), do: "?"

  defp build_initials(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search_programs", %{"search" => query}, socket) do
    {:noreply, assign(socket, search_query: query)}
  end

  @impl true
  def handle_event("filter_by_staff", %{"staff_filter" => staff_id}, socket) do
    {:noreply, assign(socket, selected_staff: staff_id)}
  end

  defp filtered_programs(programs, search_query, selected_staff) do
    programs
    |> filter_by_search(search_query)
    |> filter_by_staff(selected_staff)
  end

  defp filter_by_search(programs, ""), do: programs

  defp filter_by_search(programs, query) do
    query_lower = String.downcase(query)

    Enum.filter(programs, fn program ->
      String.contains?(String.downcase(program.name), query_lower)
    end)
  end

  defp filter_by_staff(programs, "all"), do: programs

  defp filter_by_staff(programs, staff_id) do
    staff_id_int = String.to_integer(staff_id)

    Enum.filter(programs, fn program ->
      program.assigned_staff && program.assigned_staff.id == staff_id_int
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen", Theme.bg(:muted)]}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <.provider_dashboard_header business={@business} />
        <.provider_nav_tabs live_action={@live_action} />

        <%= case @live_action do %>
          <% :overview -> %>
            <.overview_section stats={@stats} business={@business} />
          <% :team -> %>
            <.team_section team={@team} />
          <% :programs -> %>
            <.programs_section
              programs={filtered_programs(@programs, @search_query, @selected_staff)}
              staff_options={@staff_options}
              search_query={@search_query}
              selected_staff={@selected_staff}
            />
        <% end %>
      </div>
    </div>
    """
  end

  defp overview_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <.provider_stat_card
          label={gettext("Total Revenue")}
          value={format_currency(@stats.total_revenue)}
          icon="hero-currency-euro-mini"
          icon_bg="bg-green-100"
          icon_color="text-green-600"
        />
        <.provider_stat_card
          label={gettext("Active Bookings")}
          value={to_string(@stats.active_bookings)}
          icon="hero-calendar-days-mini"
          icon_bg="bg-hero-cyan-100"
          icon_color="text-hero-cyan"
        />
        <.provider_stat_card
          label={gettext("Profile Views")}
          value={format_number(@stats.profile_views)}
          icon="hero-eye-mini"
          icon_bg="bg-purple-100"
          icon_color="text-purple-600"
        />
        <.provider_stat_card
          label={gettext("Avg Rating")}
          value={to_string(@stats.average_rating)}
          icon="hero-star-mini"
          icon_bg="bg-hero-yellow-100"
          icon_color="text-hero-yellow"
        />
      </div>

      <.business_profile_card business={@business} />
    </div>
    """
  end

  defp team_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 class="text-xl font-semibold text-hero-charcoal">
            {gettext("Team & Provider Profiles")}
          </h2>
          <p class="text-sm text-hero-grey-500">
            {gettext(
              "Create profiles for your staff. These will be visible to parents when assigned to programs."
            )}
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
          <.icon name="hero-user-plus-mini" class="w-5 h-5" />
          {gettext("Add Team Member")}
        </button>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <.team_member_card :for={member <- @team} member={member} />
        <.add_card_button label={gettext("Add New Profile")} icon="hero-user-plus-mini" />
      </div>
    </div>
    """
  end

  defp programs_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <.programs_table
        programs={@programs}
        staff_options={@staff_options}
        search_query={@search_query}
        selected_staff={@selected_staff}
      />
    </div>
    """
  end

  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.replace(~r/(\d)(?=(\d{3})+$)/, "\\1,")
  end

  defp format_currency(amount), do: format_number(amount)
end
