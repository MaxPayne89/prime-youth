defmodule KlassHeroWeb.DashboardLive do
  use KlassHeroWeb, :live_view

  import KlassHeroWeb.BookingComponents, only: [info_box: 1]
  import KlassHeroWeb.CompositeComponents
  import KlassHeroWeb.ProgramComponents, only: [program_card: 1]

  alias KlassHero.Enrollment
  alias KlassHero.Family
  alias KlassHero.ProgramCatalog
  alias KlassHeroWeb.Presenters.ChildPresenter
  alias KlassHeroWeb.Presenters.ProgramPresenter
  alias KlassHeroWeb.Theme

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    # Trigger: enrollments are stored with parent_id (Family context), not identity_id (Accounts)
    # Why: user.id is the Accounts identity_id, but enrollment.parent_id is the Family parent profile ID
    # Outcome: resolve parent profile once, then query children + enrollments in parallel
    {children, active_programs, expired_programs} =
      try do
        case Family.get_parent_by_identity(user.id) do
          {:ok, parent} ->
            # Children and family programs are independent — fetch in parallel
            children_task = Task.async(fn -> Family.get_children(parent.id) end)
            {active, expired} = load_family_programs(parent.id)
            {Task.await(children_task), active, expired}

          {:error, _} ->
            {[], [], []}
        end
      rescue
        # Trigger: database or linked-task failure during dashboard data loading
        # Why: a failing section should not crash the entire dashboard
        # Outcome: gracefully degrade to empty state if any load fails
        e ->
          Logger.error("[DashboardLive] Failed to load dashboard data: #{Exception.message(e)}")

          {[], [], []}
      end

    children_for_view = Enum.map(children, &ChildPresenter.to_profile_view/1)
    children_extended = Enum.map(children, &ChildPresenter.to_extended_view/1)

    socket =
      socket
      |> assign(
        page_title: gettext("Dashboard"),
        user: user,
        children_count: length(children_for_view),
        activity_goal: calculate_activity_goal(children_extended),
        family_programs_empty?: active_programs == [] and expired_programs == []
      )
      |> stream(:children, children_for_view)
      |> stream(:family_programs, build_family_program_items(active_programs, expired_programs))
      |> assign_booking_usage_info()

    {:ok, socket}
  end

  defp calculate_activity_goal(children) do
    goal = Family.calculate_activity_goal(children)
    Map.put(goal, :message, goal_message(goal.status, goal.percentage))
  end

  defp goal_message(:achieved, _percentage), do: gettext("Congratulations! Goal achieved!")
  defp goal_message(:almost_there, _percentage), do: gettext("Almost there! One more to go!")
  defp goal_message(:in_progress, 0), do: gettext("You're just getting started!")
  defp goal_message(:in_progress, _percentage), do: gettext("You're doing great! Keep it up!")

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

  defp load_family_programs(parent_id) do
    enrollments = Enrollment.list_parent_enrollments(parent_id)

    program_ids = Enum.map(enrollments, & &1.program_id)
    programs_by_id = ProgramCatalog.get_programs_by_ids(program_ids) |> Map.new(&{&1.id, &1})

    enrollment_programs =
      Enum.flat_map(enrollments, fn enrollment ->
        case Map.fetch(programs_by_id, enrollment.program_id) do
          {:ok, program} ->
            [{enrollment, program}]

          :error ->
            # Trigger: enrollment references a program that no longer exists
            # Why: program may have been deleted; orphaned enrollment is a data issue
            # Outcome: skip this enrollment but log for data hygiene monitoring
            Logger.warning("[DashboardLive] Enrollment references missing program",
              enrollment_id: enrollment.id,
              program_id: enrollment.program_id
            )

            []
        end
      end)

    Enrollment.classify_family_programs(enrollment_programs, Date.utc_today())
  end

  # Trigger: streams require items with an :id field
  # Why: active and expired programs merge into one stream with an expired flag per item
  # Outcome: single stream preserving active-first ordering with expired metadata
  defp build_family_program_items(active, expired) do
    active_items =
      Enum.map(active, fn {e, p} ->
        %{id: e.id, enrollment: e, program: p, expired: false}
      end)

    expired_items =
      Enum.map(expired, fn {e, p} ->
        %{id: e.id, enrollment: e, program: p, expired: true}
      end)

    active_items ++ expired_items
  end

  @impl true
  def handle_event("program_click", %{"program-id" => program_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/programs/#{program_id}")}
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
            <.link navigate={~p"/settings/children"} class="text-hero-cyan hover:text-hero-cyan/80">
              {gettext("View All")}
            </.link>
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
              <.link
                navigate={~p"/settings/children/new"}
                class="w-full h-full min-h-[120px] border-2 border-dashed border-hero-grey-200 rounded-2xl flex items-center justify-center gap-2 text-hero-grey-500 hover:border-hero-cyan hover:text-hero-cyan transition-colors"
              >
                <.icon name="hero-plus-mini" class="w-6 h-6" />
                <span>{gettext("Add Child")}</span>
              </.link>
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
        <%!-- Family Achievements - commented out until achievements backend exists --%>
        <%!--
        <section class="mb-8">
          <.family_achievements achievements={@achievements} />
        </section>
        --%>
        <%!-- Family Programs --%>
        <section id="family-programs" class="mb-8">
          <div class="flex items-center gap-2 mb-4">
            <.icon name="hero-academic-cap-mini" class="w-6 h-6 text-hero-cyan" />
            <h2 class="text-xl font-semibold text-hero-charcoal">
              {gettext("Family Programs")}
            </h2>
          </div>

          <%= if @family_programs_empty? do %>
            <div id="family-programs-empty" class="text-center py-12 bg-white rounded-2xl shadow-sm">
              <.icon name="hero-book-open" class="w-12 h-12 text-hero-grey-300 mx-auto mb-4" />
              <p class="text-hero-grey-500 mb-4">
                {gettext("No programs booked yet")}
              </p>
              <.link
                navigate={~p"/programs"}
                class={[
                  "inline-flex items-center px-6 py-3 text-white font-medium",
                  "bg-hero-blue-600 hover:bg-hero-blue-700",
                  Theme.rounded(:lg),
                  Theme.transition(:normal)
                ]}
              >
                {gettext("Book a Program")}
              </.link>
            </div>
          <% else %>
            <div
              id="family-programs-list"
              phx-update="stream"
              class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
            >
              <.program_card
                :for={{dom_id, item} <- @streams.family_programs}
                id={dom_id}
                program={ProgramPresenter.to_card_view(item.program)}
                variant={:detailed}
                expired={item.expired}
                contact_url={if(!item.expired, do: ~p"/messages")}
                phx-click="program_click"
                phx-value-program-id={item.program.id}
              />
            </div>
          <% end %>
        </section>
        <%!-- Recommended Programs - commented out until recommendation engine exists --%>
        <%!--
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
                  {ProgramPresenter.format_schedule_brief(program)}
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
        --%>
        <%!-- Refer & Earn - commented out until referral tracking (count/points) exists --%>
        <%!--
        <section class="mb-8">
          <.referral_card referral_stats={@referral_stats} />
        </section>
        --%>
      </div>
    </div>
    """
  end
end
