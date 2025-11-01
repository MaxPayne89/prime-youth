defmodule PrimeYouthWeb.DashboardLive do
  use PrimeYouthWeb, :live_view

  import PrimeYouthWeb.CompositeComponents
  import PrimeYouthWeb.Live.SampleFixtures

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Dashboard")
      |> assign(current_user: sample_user())
      |> assign(user: sample_user())
      |> assign(children: sample_children(:extended))
      |> assign(upcoming_activities: sample_upcoming_activities())

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_auth", _params, socket) do
    new_user = if !socket.assigns.current_user, do: sample_user()

    {:noreply,
     socket
     |> assign(current_user: new_user)
     |> assign(user: new_user || %{name: "Guest", avatar: ""})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Profile Header -->
      <.page_header variant={:gradient} rounded>
        <:profile>
          <img
            src={@user.avatar}
            alt="Profile"
            class="w-12 h-12 rounded-full border-2 border-white/30"
          />
          <div>
            <h2 class="text-xl font-bold">{@user.name}</h2>
            <p class="text-white/80 text-sm">{length(@children)} children enrolled</p>
          </div>
        </:profile>
        <:actions>
          <button class="p-2 bg-white/20 rounded-full hover:bg-white/30 transition-colors">
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
            class="p-2 bg-white/20 rounded-full hover:bg-white/30 transition-colors"
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
            <h3 class="text-lg font-semibold text-gray-800 flex items-center">
              <svg
                class="w-5 h-5 mr-2 text-prime-cyan-400"
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
              My Children
            </h3>
            <button class="text-prime-cyan-400 text-sm font-medium hover:text-prime-cyan-400/80">
              View All
            </button>
          </div>
          <div class="space-y-3 md:grid md:grid-cols-2 lg:grid-cols-1 xl:grid-cols-2 md:gap-4 md:space-y-0">
            <.child_card
              :for={child <- @children}
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
          <h3 class="text-lg font-semibold text-gray-800 mb-4">Quick Actions</h3>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <.quick_action_button
              icon="hero-calendar"
              label="Book Activity"
              bg_color="bg-prime-cyan-100"
              icon_color="text-prime-cyan-400"
            />
            <.quick_action_button
              icon="hero-clock"
              label="View Schedule"
              bg_color="bg-prime-magenta-100"
              icon_color="text-prime-magenta-400"
            />
            <.quick_action_button
              icon="hero-chat-bubble-left-right"
              label="Messages"
              bg_color="bg-prime-yellow-100"
              icon_color="text-prime-yellow-400"
            />
            <.quick_action_button
              icon="hero-credit-card"
              label="Payments"
              bg_color="bg-green-100"
              icon_color="text-green-500"
            />
          </div>
        </div>
        
    <!-- Upcoming Activities -->
        <div>
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-semibold text-gray-800">Upcoming Activities</h3>
            <button class="text-prime-cyan-400 text-sm font-medium hover:text-prime-cyan-400/80">
              View All
            </button>
          </div>
          <div class="space-y-3">
            <.activity_card
              :for={activity <- @upcoming_activities}
              status={activity.status}
              status_color={activity.status_color}
              time={activity.time}
              name={activity.name}
              instructor={activity.instructor}
            />
            <.empty_state
              :if={Enum.empty?(@upcoming_activities)}
              icon_path="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5"
              title="No upcoming activities"
              description="Check back later for scheduled programs, or browse available programs to book a new activity."
            />
          </div>
        </div>
      </div>
    </div>
    """
  end
end
