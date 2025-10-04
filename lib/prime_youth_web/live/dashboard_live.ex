defmodule PrimeYouthWeb.DashboardLive do
  use PrimeYouthWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Dashboard")
      |> assign(user: sample_user())
      |> assign(children: sample_children())
      |> assign(upcoming_activities: sample_upcoming_activities())

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Profile Header -->
      <div class="bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 text-white p-6 rounded-b-3xl">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <img
              src={@user.avatar}
              alt="Profile"
              class="w-12 h-12 rounded-full border-2 border-white/30"
            />
            <div>
              <h2 class="text-xl font-bold">{@user.name}</h2>
              <p class="text-white/80 text-sm">{length(@children)} children enrolled</p>
            </div>
          </div>
          <div class="flex space-x-2">
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
            <button class="p-2 bg-white/20 rounded-full hover:bg-white/30 transition-colors">
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
            </button>
          </div>
        </div>
      </div>
      
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
            <div
              :for={child <- @children}
              class="bg-white rounded-2xl p-4 shadow-sm border border-gray-100 hover:shadow-md transition-shadow"
            >
              <div class="flex items-start justify-between mb-3">
                <div class="flex-1">
                  <h4 class="font-semibold text-gray-900">{child.name}</h4>
                  <p class="text-sm text-gray-600">{child.age} years old • {child.school}</p>
                </div>
                <div class="text-right">
                  <div class="text-sm font-medium text-gray-900">{child.sessions}</div>
                  <div class="text-xs text-gray-500">Sessions</div>
                </div>
              </div>
              <div class="mb-3">
                <div class="flex justify-between text-xs text-gray-600 mb-1">
                  <span>Progress</span>
                  <span>{child.progress}%</span>
                </div>
                <div class="w-full bg-gray-200 rounded-full h-2">
                  <div class="bg-prime-cyan-400 h-2 rounded-full" style={"width: #{child.progress}%"}>
                  </div>
                </div>
              </div>
              <div class="flex flex-wrap gap-1">
                <span
                  :for={activity <- child.activities}
                  class="px-2 py-1 bg-gray-100 text-gray-700 rounded-full text-xs"
                >
                  {activity}
                </span>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Quick Actions -->
        <div>
          <h3 class="text-lg font-semibold text-gray-800 mb-4">Quick Actions</h3>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <button class="bg-white rounded-2xl p-4 shadow-sm border border-gray-100 hover:shadow-md transition-all hover:scale-[1.02] group">
              <div class="w-10 h-10 bg-prime-cyan-100 rounded-full flex items-center justify-center mb-3 group-hover:bg-prime-cyan-200 transition-colors">
                <svg
                  class="w-5 h-5 text-prime-cyan-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                  >
                  </path>
                </svg>
              </div>
              <div class="text-sm font-medium text-gray-900">Book Activity</div>
            </button>
            <button class="bg-white rounded-2xl p-4 shadow-sm border border-gray-100 hover:shadow-md transition-all hover:scale-[1.02] group">
              <div class="w-10 h-10 bg-prime-magenta-100 rounded-full flex items-center justify-center mb-3 group-hover:bg-prime-magenta-200 transition-colors">
                <svg
                  class="w-5 h-5 text-prime-magenta-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                  >
                  </path>
                </svg>
              </div>
              <div class="text-sm font-medium text-gray-900">View Schedule</div>
            </button>
            <button class="bg-white rounded-2xl p-4 shadow-sm border border-gray-100 hover:shadow-md transition-all hover:scale-[1.02] group">
              <div class="w-10 h-10 bg-prime-yellow-100 rounded-full flex items-center justify-center mb-3 group-hover:bg-prime-yellow-200 transition-colors">
                <svg
                  class="w-5 h-5 text-prime-yellow-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
                  >
                  </path>
                </svg>
              </div>
              <div class="text-sm font-medium text-gray-900">Messages</div>
            </button>
            <button class="bg-white rounded-2xl p-4 shadow-sm border border-gray-100 hover:shadow-md transition-all hover:scale-[1.02] group">
              <div class="w-10 h-10 bg-green-100 rounded-full flex items-center justify-center mb-3 group-hover:bg-green-200 transition-colors">
                <svg
                  class="w-5 h-5 text-green-500"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"
                  >
                  </path>
                </svg>
              </div>
              <div class="text-sm font-medium text-gray-900">Payments</div>
            </button>
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
            <div
              :for={activity <- @upcoming_activities}
              class="bg-white rounded-2xl p-4 shadow-sm border border-gray-100 hover:shadow-md transition-shadow"
            >
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <div class="flex items-center mb-2">
                    <span class={"px-2 py-1 rounded-full text-xs font-medium #{activity.status_color}"}>
                      {activity.status}
                    </span>
                    <span class="ml-2 text-sm text-gray-600">{activity.time}</span>
                  </div>
                  <h4 class="font-semibold text-gray-900 mb-1">{activity.name}</h4>
                  <p class="text-sm text-gray-600">Instructor: {activity.instructor}</p>
                </div>
                <div class="text-right">
                  <div class="w-10 h-10 bg-gray-100 rounded-full flex items-center justify-center">
                    <svg
                      class="w-5 h-5 text-gray-500"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M9 5l7 7-7 7"
                      >
                      </path>
                    </svg>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Sample data functions
  defp sample_user do
    %{
      name: "Sarah Johnson",
      avatar:
        "https://images.unsplash.com/photo-1494790108755-2616b612b388?w=64&h=64&fit=crop&crop=face"
    }
  end

  defp sample_children do
    [
      %{
        id: 1,
        name: "Emma Johnson",
        age: 8,
        school: "Greenwood Elementary",
        sessions: "8/10",
        progress: 80,
        activities: ["Art", "Chess", "Swimming"]
      },
      %{
        id: 2,
        name: "Liam Johnson",
        age: 6,
        school: "Sunny Hills Kindergarten",
        sessions: "6/8",
        progress: 75,
        activities: ["Soccer", "Music"]
      }
    ]
  end

  defp sample_upcoming_activities do
    [
      %{
        id: 1,
        name: "Creative Art World",
        instructor: "Ms. Rodriguez",
        time: "Today, 4:00 PM",
        status: "Today",
        status_color: "bg-red-100 text-red-700"
      },
      %{
        id: 2,
        name: "Chess Masters",
        instructor: "Mr. Chen",
        time: "Tomorrow, 3:30 PM",
        status: "Tomorrow",
        status_color: "bg-orange-100 text-orange-700"
      },
      %{
        id: 3,
        name: "Swimming Lessons",
        instructor: "Coach Davis",
        time: "Friday, 2:00 PM",
        status: "This Week",
        status_color: "bg-blue-100 text-blue-700"
      }
    ]
  end
end
