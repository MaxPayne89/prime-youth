defmodule KlassHeroWeb.DashboardLive do
  use KlassHeroWeb, :live_view

  import KlassHeroWeb.CompositeComponents

  alias KlassHero.Identity
  alias KlassHeroWeb.Presenters.ChildPresenter
  alias KlassHeroWeb.Theme

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    children = get_children_for_parent(socket)
    children_for_view = Enum.map(children, &ChildPresenter.to_profile_view/1)
    children_extended = Enum.map(children, &ChildPresenter.to_extended_view/1)

    socket =
      socket
      |> assign(page_title: gettext("Dashboard"))
      |> assign(user: user)
      |> assign(children_count: length(children_for_view))
      |> assign(activity_goal: calculate_activity_goal(children_extended))
      |> assign(achievements: get_achievements(socket))
      |> assign(recommended_programs: get_recommended_programs(socket))
      |> assign(referral_stats: get_referral_stats(user))
      |> stream(:children, children_for_view)

    {:ok, socket}
  end

  defp get_children_for_parent(socket) do
    with %{current_scope: %{user: %{id: identity_id}}} <- socket.assigns,
         {:ok, parent} <- Identity.get_parent_by_identity(identity_id) do
      Identity.get_children(parent.id)
    else
      _ -> []
    end
  end

  defp calculate_activity_goal(children) do
    current =
      Enum.reduce(children, 0, fn c, acc ->
        session_count =
          case c.sessions do
            sessions when is_list(sessions) -> length(sessions)
            sessions when is_binary(sessions) -> parse_session_count(sessions)
            _ -> 0
          end

        acc + session_count
      end)

    target = 5
    percentage = min(100, div(current * 100, max(target, 1)))

    %{
      current: current,
      target: target,
      percentage: percentage,
      message: goal_message(percentage)
    }
  end

  defp parse_session_count(sessions_string) do
    case String.split(sessions_string, "/") do
      [current, _total] ->
        case Integer.parse(current) do
          {count, _} -> count
          :error -> 0
        end

      _ ->
        0
    end
  end

  defp goal_message(percentage) when percentage >= 100,
    do: gettext("Congratulations! Goal achieved!")

  defp goal_message(percentage) when percentage >= 80,
    do: gettext("Almost there! One more to go!")

  defp goal_message(_), do: gettext("You're doing great! Keep it up!")

  defp get_achievements(_socket) do
    [
      %{emoji: "🌍", name: gettext("Activity Explorer"), date: "2023-11-15"},
      %{emoji: "⭐", name: gettext("Super Reviewer"), date: "2024-01-20"},
      %{emoji: "🎨", name: gettext("Art Pro"), date: "2024-02-10"},
      %{emoji: "⚽", name: gettext("Sporty Kid"), date: "2024-03-01"}
    ]
  end

  defp get_recommended_programs(_socket) do
    # Mock empty list for now - will be populated when program catalog is implemented
    []
  end

  defp get_referral_stats(user) do
    %{
      count: 3,
      points: 600,
      code: generate_referral_code(user)
    }
  end

  defp generate_referral_code(user) do
    [first_name | _] = String.split(user.name, " ")
    "#{String.upcase(first_name)}-BERLIN-24"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen", Theme.bg(:muted)]}>
      <!-- Profile Header -->
      <.page_header variant={:gradient} rounded>
        <:profile>
          <img
            src={@user.avatar}
            alt="Profile"
            class={["w-12 h-12 border-2 border-white/30", Theme.rounded(:full)]}
          />
          <div>
            <h2 class={Theme.typography(:card_title)}>{@user.name}</h2>
            <p class="text-white/80 text-sm">
              {ngettext("%{count} child enrolled", "%{count} children enrolled", @children_count,
                count: @children_count
              )}
            </p>
          </div>
        </:profile>
        <:actions>
          <button class={[
            "p-2 bg-white/20 hover:bg-white/30",
            Theme.transition(:normal),
            Theme.rounded(:full)
          ]}>
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M15 17h5l-5 5-5-5h5v-7a1 1 0 011-1h3a1 1 0 011 1v7z"
              >
              </path>
            </svg>
          </button>
          <.link
            navigate={~p"/settings"}
            class={[
              "p-2 bg-white/20 hover:bg-white/30",
              Theme.transition(:normal),
              Theme.rounded(:full)
            ]}
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
              >
              </path>
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
              >
              </path>
            </svg>
          </.link>
        </:actions>
      </.page_header>
      
    <!-- Content Area -->
      <div class="p-6 space-y-6">
        <!-- Children Profiles - Horizontal Scroll -->
        <section class="mb-8">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-xl font-semibold text-hero-charcoal flex items-center gap-2">
              <.icon name="hero-user-group-mini" class="w-6 h-6 text-hero-cyan" />
              <%= gettext("My Children") %>
            </h2>
            <%!-- Placeholder link - will navigate to /children when children management page is implemented --%>
            <span class="text-hero-cyan cursor-not-allowed opacity-50">
              <%= gettext("View All") %>
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
            <div class="flex-shrink-0 w-64 snap-start">
              <button class="w-full h-full min-h-[120px] border-2 border-dashed border-hero-grey-200 rounded-2xl flex items-center justify-center gap-2 text-hero-grey-500 hover:border-hero-cyan hover:text-hero-cyan transition-colors">
                <.icon name="hero-plus-mini" class="w-6 h-6" />
                <span><%= gettext("Add Child") %></span>
              </button>
            </div>
          </div>
        </section>
        <%!-- Weekly Activity Goal --%>
        <section class="mb-8">
          <.weekly_goal_card goal={@activity_goal} />
        </section>

    <!-- Quick Actions -->
        <div>
          <h3 class={[Theme.typography(:card_title), "mb-4", Theme.text_color(:body)]}>
            {gettext("Quick Actions")}
          </h3>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <.quick_action_button
              icon="hero-calendar"
              label={gettext("Book Activity")}
              bg_color={Theme.bg(:primary_light)}
              icon_color={Theme.text_color(:primary)}
            />
            <.quick_action_button
              icon="hero-clock"
              label={gettext("View Schedule")}
              bg_color={Theme.bg(:secondary_light)}
              icon_color={Theme.text_color(:secondary)}
            />
            <.quick_action_button
              icon="hero-chat-bubble-left-right"
              label={gettext("Messages")}
              bg_color={Theme.bg(:accent_light)}
              icon_color={Theme.text_color(:accent)}
            />
            <.quick_action_button
              icon="hero-credit-card"
              label={gettext("Payments")}
              bg_color={Theme.bg(:primary_light)}
              icon_color={Theme.text_color(:primary)}
            />
          </div>
        </div>
        <%!-- Family Achievements --%>
        <section class="mb-8">
          <.family_achievements achievements={@achievements} />
        </section>
        <%!-- Recommended Programs --%>
        <section class="mb-8" :if={@recommended_programs != []}>
          <div class="flex items-center gap-2 mb-4">
            <.icon name="hero-sparkles-mini" class="w-6 h-6 text-hero-yellow" />
            <h2 class="text-xl font-semibold text-hero-charcoal">
              <%= gettext("Recommended For You") %>
            </h2>
          </div>

          <p class="text-hero-grey-500 mb-4">
            <%= gettext("Based on your children's interests") %>
          </p>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <div :for={program <- @recommended_programs}>
              <%!-- Program cards will be implemented when Program Catalog context is ready --%>
              <div class="bg-white rounded-2xl shadow-md p-4">
                <p class="text-hero-grey-500">{program.title}</p>
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
