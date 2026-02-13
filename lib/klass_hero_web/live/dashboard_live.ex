defmodule KlassHeroWeb.DashboardLive do
  use KlassHeroWeb, :live_view

  import KlassHeroWeb.BookingComponents, only: [info_box: 1]
  import KlassHeroWeb.CompositeComponents
  import KlassHeroWeb.Helpers.FamilyHelpers

  alias KlassHero.Enrollment
  alias KlassHero.Family
  alias KlassHeroWeb.Presenters.ChildPresenter
  alias KlassHeroWeb.Theme

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    children = get_children_for_current_user(socket)
    children_for_view = Enum.map(children, &ChildPresenter.to_profile_view/1)
    children_extended = Enum.map(children, &ChildPresenter.to_extended_view/1)

    socket =
      socket
      |> assign(
        page_title: gettext("Dashboard"),
        user: user,
        children_count: length(children_for_view),
        activity_goal: calculate_activity_goal(children_extended),
        achievements: get_achievements(socket),
        recommended_programs: get_recommended_programs(socket),
        referral_stats: get_referral_stats(user)
      )
      |> stream(:children, children_for_view)
      |> assign_booking_usage_info()

    {:ok, socket}
  end

  defp calculate_activity_goal(children) do
    goal = Family.calculate_activity_goal(children)
    Map.put(goal, :message, goal_message(goal.status))
  end

  defp goal_message(:achieved), do: gettext("Congratulations! Goal achieved!")
  defp goal_message(:almost_there), do: gettext("Almost there! One more to go!")
  defp goal_message(:in_progress), do: gettext("You're doing great! Keep it up!")

  defp get_achievements(_socket) do
    [
      %{emoji: "🌍", name: gettext("Activity Explorer"), date: "2023-11-15"},
      %{emoji: "⭐", name: gettext("Super Reviewer"), date: "2024-01-20"},
      %{emoji: "🎨", name: gettext("Art Pro"), date: "2024-02-10"},
      %{emoji: "⚽", name: gettext("Sporty Kid"), date: "2024-03-01"}
    ]
  end

  defp get_recommended_programs(socket) do
    children = get_children_for_current_user(socket)
    first_child_name = get_first_child_name(children)

    %{
      child_name: first_child_name,
      programs: [
        %{
          id: 1,
          title: gettext("Creative Art Workshop"),
          category: gettext("Arts & Crafts"),
          age_range: "6-12",
          schedule: gettext("Saturdays 10:00 AM"),
          price: "€15",
          image_url: "https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=400"
        },
        %{
          id: 2,
          title: gettext("Junior Soccer Academy"),
          category: gettext("Sports"),
          age_range: "5-10",
          schedule: gettext("Tuesdays & Thursdays 4:00 PM"),
          price: "€20",
          image_url: "https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=400"
        },
        %{
          id: 3,
          title: gettext("Coding for Kids"),
          category: gettext("Technology"),
          age_range: "8-14",
          schedule: gettext("Wednesdays 3:30 PM"),
          price: "€25",
          image_url: "https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=400"
        }
      ]
    }
  end

  defp get_first_child_name(children) do
    case children do
      [first | _] -> first.first_name || gettext("Your Child")
      [] -> gettext("Your Child")
    end
  end

  defp get_referral_stats(user) do
    %{
      count: 3,
      points: 600,
      code: generate_referral_code(user)
    }
  end

  defp generate_referral_code(user) do
    Family.generate_referral_code(user.name)
  end

  defp assign_booking_usage_info(socket) do
    identity_id = socket.assigns.user.id

    case Enrollment.get_booking_usage_info(identity_id) do
      {:ok, info} when info.cap != :unlimited ->
        assign(socket,
          show_booking_usage: true,
          booking_tier: info.tier,
          booking_cap: info.cap,
          bookings_used: info.used,
          bookings_remaining: info.remaining
        )

      _ ->
        assign(socket, show_booking_usage: false)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen", Theme.bg(:muted)]}>
      <!-- Content Area -->
      <div class="p-6 space-y-6">
        <!-- Children Profiles - Horizontal Scroll -->
        <section class="mb-8">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-xl font-semibold text-hero-charcoal flex items-center gap-2">
              <.icon name="hero-user-group-mini" class="w-6 h-6 text-hero-cyan" />
              {gettext("My Children")}
            </h2>
            <%!-- Placeholder link - will navigate to /children when children management page is implemented --%>
            <span class="text-hero-cyan cursor-not-allowed opacity-50">
              {gettext("View All")}
            </span>
          </div>

          <div
            id="children"
            phx-update="stream"
            class="flex overflow-x-auto snap-x snap-mandatory gap-4 pb-4 -mx-4 px-4"
          >
            <div :for={{dom_id, child} <- @streams.children} id={dom_id}>
              <.child_profile_card child={child} />
            </div>
            <%!-- Add Child Button --%>
            <div id="add-child-button" class="flex-shrink-0 w-64 snap-start">
              <button class="w-full h-full min-h-[120px] border-2 border-dashed border-hero-grey-200 rounded-2xl flex items-center justify-center gap-2 text-hero-grey-500 hover:border-hero-cyan hover:text-hero-cyan transition-colors">
                <.icon name="hero-plus-mini" class="w-6 h-6" />
                <span>{gettext("Add Child")}</span>
              </button>
            </div>
          </div>
        </section>
        <%!-- Weekly Activity Goal --%>
        <section class="mb-8">
          <.weekly_goal_card goal={@activity_goal} />
        </section>
        <%!-- Monthly Booking Usage (limited tiers only) --%>
        <section :if={@show_booking_usage} class="mb-8">
          <.info_box
            variant={:info}
            icon="📊"
            title={gettext("Monthly Booking Usage")}
          >
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm">
                  {gettext("You have used %{used} of %{cap} bookings this month.",
                    used: @bookings_used,
                    cap: @booking_cap
                  )}
                </p>
                <p class="text-lg font-semibold text-hero-blue-600 mt-1">
                  {gettext("%{remaining} remaining", remaining: @bookings_remaining)}
                </p>
                <p class="text-xs text-hero-grey-500 mt-1">
                  <span class="capitalize">{@booking_tier}</span> {gettext("tier")}
                </p>
              </div>
              <.link
                navigate={~p"/settings"}
                class="text-sm text-hero-blue-600 hover:text-hero-blue-800 underline"
              >
                {gettext("Upgrade")}
              </.link>
            </div>
          </.info_box>
        </section>
        <%!-- Family Achievements --%>
        <section class="mb-8">
          <.family_achievements achievements={@achievements} />
        </section>
        <%!-- Recommended Programs --%>
        <section class="mb-8">
          <div class="flex items-center gap-2 mb-4">
            <.icon name="hero-sparkles-mini" class="w-6 h-6 text-hero-cyan" />
            <h2 class="text-xl font-semibold text-hero-charcoal">
              {gettext("Recommended for %{name}", name: @recommended_programs.child_name)}
            </h2>
          </div>

          <p class="text-hero-grey-500 mb-4">
            {gettext("Based on your children's interests")}
          </p>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <div
              :for={program <- @recommended_programs.programs}
              class="bg-white rounded-2xl shadow-md overflow-hidden"
            >
              <img
                src={program.image_url}
                alt={program.title}
                class="w-full h-32 object-cover"
              />
              <div class="p-4">
                <span class="inline-block px-2 py-1 text-xs font-medium bg-hero-blue-100 text-hero-blue-600 rounded-full mb-2">
                  {program.category}
                </span>
                <h3 class="font-semibold text-hero-charcoal mb-1">{program.title}</h3>
                <p class="text-sm text-hero-grey-500 mb-2">
                  <.icon name="hero-clock-mini" class="w-4 h-4 inline mr-1" />
                  {program.schedule}
                </p>
                <div class="flex justify-between items-center">
                  <span class="text-sm text-hero-grey-400">
                    {gettext("Ages")} {program.age_range}
                  </span>
                  <span class="font-semibold text-hero-blue-600">{program.price}</span>
                </div>
              </div>
            </div>
          </div>
        </section>
        <%!-- Refer & Earn --%>
        <section class="mb-8">
          <.referral_card referral_stats={@referral_stats} />
        </section>
      </div>
    </div>
    """
  end
end
