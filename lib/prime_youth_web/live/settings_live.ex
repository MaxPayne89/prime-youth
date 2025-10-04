defmodule PrimeYouthWeb.SettingsLive do
  use PrimeYouthWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Settings")
      |> assign(current_user: sample_user())
      |> assign(user: sample_user())

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_auth", _params, socket) do
    new_user = if socket.assigns.current_user, do: nil, else: sample_user()
    {:noreply, assign(socket, current_user: new_user, user: new_user)}
  end

  @impl true
  def handle_event("navigate_to", %{"section" => section}, socket) do
    # Placeholder for future navigation
    # Will navigate to detail pages for each section
    IO.puts("Navigate to: #{section}")
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Header -->
      <div class="bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 text-white p-6">
        <div class="max-w-4xl mx-auto">
          <h1 class="text-2xl font-bold">Settings</h1>
          <p class="text-white/80 text-sm mt-1">Manage your account and preferences</p>
        </div>
      </div>

      <!-- Content -->
      <div class="max-w-4xl mx-auto p-4 space-y-4">
        <!-- Account & Profile Section -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">Account & Profile</h3>
          </div>
          <div>
            <button
              phx-click="navigate_to"
              phx-value-section="profile-information"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors border-b border-gray-100"
            >
              <div class="w-10 h-10 bg-prime-cyan-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-prime-cyan-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">Profile Information</div>
                <div class="text-sm text-gray-500">Name, email, profile photo</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
            <button
              phx-click="navigate_to"
              phx-value-section="privacy-security"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors"
            >
              <div class="w-10 h-10 bg-prime-magenta-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-prime-magenta-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">Privacy & Security</div>
                <div class="text-sm text-gray-500">Account preferences, password</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
          </div>
        </div>

        <!-- My Family Section -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">My Family</h3>
          </div>
          <div>
            <button
              phx-click="navigate_to"
              phx-value-section="children-profiles"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors border-b border-gray-100"
            >
              <div class="w-10 h-10 bg-prime-cyan-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-prime-cyan-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">Children Profiles</div>
                <div class="text-sm text-gray-500">{@user.children_summary}</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
            <button
              phx-click="navigate_to"
              phx-value-section="my-schedule"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors border-b border-gray-100"
            >
              <div class="w-10 h-10 bg-prime-magenta-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-prime-magenta-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">My Schedule</div>
                <div class="text-sm text-gray-500">View all family activities</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
            <button
              phx-click="navigate_to"
              phx-value-section="family-progress"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors"
            >
              <div class="w-10 h-10 bg-prime-yellow-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-prime-yellow-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">Family Progress</div>
                <div class="text-sm text-gray-500">Achievements and milestones</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
          </div>
        </div>

        <!-- Contact Information Section -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">Contact Information</h3>
          </div>
          <div>
            <button
              phx-click="navigate_to"
              phx-value-section="home-address"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors border-b border-gray-100"
            >
              <div class="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">Home Address</div>
                <div class="text-sm text-gray-500">Primary address and phone</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
            <button
              phx-click="navigate_to"
              phx-value-section="parent-guardian"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors border-b border-gray-100"
            >
              <div class="w-10 h-10 bg-purple-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">Parent/Guardian Details</div>
                <div class="text-sm text-gray-500">Contact info for both parents</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
            <button
              phx-click="navigate_to"
              phx-value-section="emergency-contacts"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors"
            >
              <div class="w-10 h-10 bg-red-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">Emergency Contacts</div>
                <div class="text-sm text-gray-500">Backup contacts for emergencies</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
          </div>
        </div>

        <!-- Health & Safety Section -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">Health & Safety</h3>
          </div>
          <div>
            <button
              phx-click="navigate_to"
              phx-value-section="medical-information"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors border-b border-gray-100"
            >
              <div class="w-10 h-10 bg-red-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">Medical Information</div>
                <div class="text-sm text-gray-500">Conditions, medications, special needs</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
            <button
              phx-click="navigate_to"
              phx-value-section="allergies-dietary"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors border-b border-gray-100"
            >
              <div class="w-10 h-10 bg-orange-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-orange-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">Allergies & Dietary</div>
                <div class="text-sm text-gray-500">Food allergies, dietary restrictions</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
            <button
              phx-click="navigate_to"
              phx-value-section="insurance-information"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors"
            >
              <div class="w-10 h-10 bg-green-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">Insurance Information</div>
                <div class="text-sm text-gray-500">Health insurance details</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
          </div>
        </div>

        <!-- Permissions & Consents Section -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">Permissions & Consents</h3>
          </div>
          <div>
            <button
              phx-click="navigate_to"
              phx-value-section="photo-video-release"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors border-b border-gray-100"
            >
              <div class="w-10 h-10 bg-purple-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"></path>
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">Photo & Video Release</div>
                <div class="text-sm text-gray-500">Marketing and social media permissions</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
            <button
              phx-click="navigate_to"
              phx-value-section="activity-permissions"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors border-b border-gray-100"
            >
              <div class="w-10 h-10 bg-green-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">Activity Permissions</div>
                <div class="text-sm text-gray-500">Swimming, field trips, group activities</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
            <button
              phx-click="navigate_to"
              phx-value-section="whatsapp-community"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors"
            >
              <div class="w-10 h-10 bg-prime-cyan-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-prime-cyan-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">WhatsApp Community</div>
                <div class="text-sm text-gray-500">Updates, discounts, family credit</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
          </div>
        </div>

        <!-- Payment & Billing Section -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">Payment & Billing</h3>
          </div>
          <div>
            <button
              phx-click="navigate_to"
              phx-value-section="payment-methods"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors border-b border-gray-100"
            >
              <div class="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">Payment Methods</div>
                <div class="text-sm text-gray-500">Cards, bank accounts, billing info</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
            <button
              phx-click="navigate_to"
              phx-value-section="transaction-history"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors border-b border-gray-100"
            >
              <div class="w-10 h-10 bg-prime-magenta-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-prime-magenta-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">Transaction History</div>
                <div class="text-sm text-gray-500">Past payments and invoices</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
            <button
              phx-click="navigate_to"
              phx-value-section="family-credits"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors"
            >
              <div class="w-10 h-10 bg-prime-yellow-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-prime-yellow-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">Family Credits & Discounts</div>
                <div class="text-sm text-gray-500">Available credits and promo codes</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
          </div>
        </div>

        <!-- Notifications & Communication Section -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">Notifications & Communication</h3>
          </div>
          <div>
            <button
              phx-click="navigate_to"
              phx-value-section="notification-preferences"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors border-b border-gray-100"
            >
              <div class="w-10 h-10 bg-prime-cyan-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-prime-cyan-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">Notification Preferences</div>
                <div class="text-sm text-gray-500">Push, email, SMS settings</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
            <button
              phx-click="navigate_to"
              phx-value-section="communication-settings"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors"
            >
              <div class="w-10 h-10 bg-prime-magenta-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-prime-magenta-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">Communication Settings</div>
                <div class="text-sm text-gray-500">How you want to be contacted</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
          </div>
        </div>

        <!-- Help & Support Section -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">Help & Support</h3>
          </div>
          <div>
            <button
              phx-click="navigate_to"
              phx-value-section="faq-help"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors border-b border-gray-100"
            >
              <div class="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">FAQ & Help Center</div>
                <div class="text-sm text-gray-500">Common questions and guides</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
            <button
              phx-click="navigate_to"
              phx-value-section="contact-support"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors border-b border-gray-100"
            >
              <div class="w-10 h-10 bg-prime-cyan-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-prime-cyan-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 5.636l-3.536 3.536m0 5.656l3.536 3.536M9.172 9.172L5.636 5.636m3.536 9.192l-3.536 3.536M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-5 0a4 4 0 11-8 0 4 4 0 018 0z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">Contact Support</div>
                <div class="text-sm text-gray-500">Get help from our team</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
            <button
              phx-click="navigate_to"
              phx-value-section="app-information"
              class="w-full flex items-center gap-4 p-4 hover:bg-gray-50 transition-colors border-b border-gray-100"
            >
              <div class="w-10 h-10 bg-purple-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-gray-900">App Information</div>
                <div class="text-sm text-gray-500">Version, terms, privacy policy</div>
              </div>
              <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
            <button
              phx-click="navigate_to"
              phx-value-section="sign-out"
              class="w-full flex items-center gap-4 p-4 hover:bg-red-50 transition-colors text-red-600"
            >
              <div class="w-10 h-10 bg-red-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"></path>
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="font-medium text-red-600">Sign Out</div>
                <div class="text-sm text-red-500">Log out of your account</div>
              </div>
              <svg class="w-5 h-5 text-red-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Sample data
  defp sample_user do
    %{
      name: "Sarah Johnson",
      email: "sarah.johnson@example.com",
      avatar:
        "https://images.unsplash.com/photo-1494790108755-2616b612b388?w=64&h=64&fit=crop&crop=face",
      children_summary: "Emma (8), Liam (6) • 2 children"
    }
  end
end
