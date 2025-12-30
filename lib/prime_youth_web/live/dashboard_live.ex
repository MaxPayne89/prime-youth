defmodule PrimeYouthWeb.DashboardLive do
  use PrimeYouthWeb, :live_view

  import PrimeYouthWeb.CompositeComponents

  alias PrimeYouth.Activities.Application.UseCases.ListUpcomingActivities
  alias PrimeYouth.Family.Application.UseCases.{GetChildren, GetCurrentUser}
  alias PrimeYouthWeb.Presenters.ChildPresenter
  alias PrimeYouthWeb.Theme

  @impl true
  def mount(_params, _session, socket) do
    {:ok, user} = GetCurrentUser.execute()
    {:ok, children} = GetChildren.execute(:extended)
    {:ok, activities} = ListUpcomingActivities.execute()

    children_for_view = Enum.map(children, &ChildPresenter.to_extended_view/1)

    socket =
      socket
      |> assign(page_title: gettext("Dashboard"))
      |> assign(user: user)
      |> assign(children_count: length(children_for_view))
      |> stream(:children, children_for_view)
      |> stream(:upcoming_activities, activities)
      |> assign(:activities_empty?, Enum.empty?(activities))

    {:ok, socket}
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
        <!-- My Children Section -->
        <div>
          <div class="flex items-center justify-between mb-4">
            <h3 class={[Theme.typography(:card_title), "flex items-center", Theme.text_color(:body)]}>
              <svg
                class={["w-5 h-5 mr-2", Theme.text_color(:primary)]}
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"
                >
                </path>
              </svg>
              {gettext("My Children")}
            </h3>
            <button class={[Theme.text_color(:primary), "text-sm font-medium hover:opacity-80"]}>
              {gettext("View All")}
            </button>
          </div>
          <div
            id="children"
            phx-update="stream"
            class="space-y-3 md:grid md:grid-cols-2 lg:grid-cols-1 xl:grid-cols-2 md:gap-4 md:space-y-0"
          >
            <.child_card
              :for={{dom_id, child} <- @streams.children}
              id={dom_id}
              name={child.name}
              age={child.age}
              school={child.school}
              sessions={child.sessions}
              progress={child.progress}
              activities={child.activities}
            />
          </div>
        </div>
        
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
        
    <!-- Upcoming Activities -->
        <div>
          <div class="flex items-center justify-between mb-4">
            <h3 class={[Theme.typography(:card_title), Theme.text_color(:body)]}>
              {gettext("Upcoming Activities")}
            </h3>
            <button class={[Theme.text_color(:primary), "text-sm font-medium hover:opacity-80"]}>
              {gettext("View All")}
            </button>
          </div>
          <div id="upcoming-activities" phx-update="stream" class="space-y-3">
            <.activity_card
              :for={{dom_id, activity} <- @streams.upcoming_activities}
              id={dom_id}
              status={activity.status}
              status_color={activity.status_color}
              time={activity.time}
              name={activity.name}
              instructor={activity.instructor}
            />
          </div>
          <.empty_state
            :if={@activities_empty?}
            icon_path="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5"
            title={gettext("No upcoming activities")}
            description={
              gettext(
                "Check back later for scheduled programs, or browse available programs to book a new activity."
              )
            }
          />
        </div>
      </div>
    </div>
    """
  end
end
