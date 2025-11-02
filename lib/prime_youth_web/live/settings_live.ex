defmodule PrimeYouthWeb.SettingsLive do
  use PrimeYouthWeb, :live_view

  import PrimeYouthWeb.CompositeComponents
  import PrimeYouthWeb.Live.SampleFixtures

  if Mix.env() == :dev do
    use PrimeYouthWeb.DevAuthToggle
  end

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
      <.page_header variant={:gradient} container_class="max-w-4xl mx-auto">
        <:title>Settings</:title>
        <:subtitle>Manage your account and preferences</:subtitle>
      </.page_header>
      
    <!-- Content -->
      <div class="max-w-4xl mx-auto p-4 space-y-4">
        <!-- Account & Profile Section -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">Account & Profile</h3>
          </div>
          <div>
            <.settings_menu_item
              icon="hero-user"
              icon_bg="bg-prime-cyan-100"
              icon_color="text-prime-cyan-400"
              title="Profile Information"
              description="Name, email, profile photo"
              phx-click="navigate_to"
              phx-value-section="profile-information"
            />
            <.settings_menu_item
              icon="hero-lock-closed"
              icon_bg="bg-prime-magenta-100"
              icon_color="text-prime-magenta-400"
              title="Privacy & Security"
              description="Account preferences, password"
              phx-click="navigate_to"
              phx-value-section="privacy-security"
            />
          </div>
        </div>
        
    <!-- My Family Section -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">My Family</h3>
          </div>
          <div>
            <.settings_menu_item
              icon="hero-user-group"
              icon_bg="bg-prime-cyan-100"
              icon_color="text-prime-cyan-400"
              title="Children Profiles"
              description={@user.children_summary}
              phx-click="navigate_to"
              phx-value-section="children-profiles"
            />
            <.settings_menu_item
              icon="hero-calendar"
              icon_bg="bg-prime-magenta-100"
              icon_color="text-prime-magenta-400"
              title="My Schedule"
              description="View all family activities"
              phx-click="navigate_to"
              phx-value-section="my-schedule"
            />
            <.settings_menu_item
              icon="hero-badge-check"
              icon_bg="bg-prime-yellow-100"
              icon_color="text-prime-yellow-400"
              title="Family Progress"
              description="Achievements and milestones"
              phx-click="navigate_to"
              phx-value-section="family-progress"
            />
          </div>
        </div>
        
    <!-- Contact Information Section -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">Contact Information</h3>
          </div>
          <div>
            <.settings_menu_item
              icon="hero-home"
              icon_bg="bg-blue-100"
              icon_color="text-blue-500"
              title="Home Address"
              description="Primary address and phone"
              phx-click="navigate_to"
              phx-value-section="home-address"
            />
            <.settings_menu_item
              icon="hero-users"
              icon_bg="bg-purple-100"
              icon_color="text-purple-500"
              title="Parent/Guardian Details"
              description="Contact info for both parents"
              phx-click="navigate_to"
              phx-value-section="parent-guardian"
            />
            <.settings_menu_item
              icon="hero-exclamation-triangle"
              icon_bg="bg-red-100"
              icon_color="text-red-500"
              title="Emergency Contacts"
              description="Backup contacts for emergencies"
              phx-click="navigate_to"
              phx-value-section="emergency-contacts"
            />
          </div>
        </div>
        
    <!-- Health & Safety Section -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">Health & Safety</h3>
          </div>
          <div>
            <.settings_menu_item
              icon="hero-heart"
              icon_bg="bg-red-100"
              icon_color="text-red-500"
              title="Medical Information"
              description="Conditions, medications, special needs"
              phx-click="navigate_to"
              phx-value-section="medical-information"
            />
            <.settings_menu_item
              icon="hero-exclamation-circle"
              icon_bg="bg-orange-100"
              icon_color="text-orange-500"
              title="Allergies & Dietary"
              description="Food allergies, dietary restrictions"
              phx-click="navigate_to"
              phx-value-section="allergies-dietary"
            />
            <.settings_menu_item
              icon="hero-shield-check"
              icon_bg="bg-green-100"
              icon_color="text-green-500"
              title="Insurance Information"
              description="Health insurance details"
              phx-click="navigate_to"
              phx-value-section="insurance-information"
            />
          </div>
        </div>
        
    <!-- Permissions & Consents Section -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">Permissions & Consents</h3>
          </div>
          <div>
            <.settings_menu_item
              icon="hero-camera"
              icon_bg="bg-purple-100"
              icon_color="text-purple-500"
              title="Photo & Video Release"
              description="Marketing and social media permissions"
              phx-click="navigate_to"
              phx-value-section="photo-video-release"
            />
            <.settings_menu_item
              icon="hero-check-circle"
              icon_bg="bg-green-100"
              icon_color="text-green-500"
              title="Activity Permissions"
              description="Swimming, field trips, group activities"
              phx-click="navigate_to"
              phx-value-section="activity-permissions"
            />
            <.settings_menu_item
              icon="hero-chat-bubble-left-right"
              icon_bg="bg-prime-cyan-100"
              icon_color="text-prime-cyan-400"
              title="WhatsApp Community"
              description="Updates, discounts, family credit"
              phx-click="navigate_to"
              phx-value-section="whatsapp-community"
            />
          </div>
        </div>
        
    <!-- Payment & Billing Section -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">Payment & Billing</h3>
          </div>
          <div>
            <.settings_menu_item
              icon="hero-credit-card"
              icon_bg="bg-blue-100"
              icon_color="text-blue-500"
              title="Payment Methods"
              description="Cards, bank accounts, billing info"
              phx-click="navigate_to"
              phx-value-section="payment-methods"
            />
            <.settings_menu_item
              icon="hero-document-text"
              icon_bg="bg-prime-magenta-100"
              icon_color="text-prime-magenta-400"
              title="Transaction History"
              description="Past payments and invoices"
              phx-click="navigate_to"
              phx-value-section="transaction-history"
            />
            <.settings_menu_item
              icon="hero-currency-dollar"
              icon_bg="bg-prime-yellow-100"
              icon_color="text-prime-yellow-400"
              title="Family Credits & Discounts"
              description="Available credits and promo codes"
              phx-click="navigate_to"
              phx-value-section="family-credits"
            />
          </div>
        </div>
        
    <!-- Notifications & Communication Section -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">Notifications & Communication</h3>
          </div>
          <div>
            <.settings_menu_item
              icon="hero-bell"
              icon_bg="bg-prime-cyan-100"
              icon_color="text-prime-cyan-400"
              title="Notification Preferences"
              description="Push, email, SMS settings"
              phx-click="navigate_to"
              phx-value-section="notification-preferences"
            />
            <.settings_menu_item
              icon="hero-envelope"
              icon_bg="bg-prime-magenta-100"
              icon_color="text-prime-magenta-400"
              title="Communication Settings"
              description="How you want to be contacted"
              phx-click="navigate_to"
              phx-value-section="communication-settings"
            />
          </div>
        </div>
        
    <!-- Help & Support Section -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
          <div class="p-4 border-b border-gray-100">
            <h3 class="font-semibold text-gray-900">Help & Support</h3>
          </div>
          <div>
            <.settings_menu_item
              icon="hero-question-mark-circle"
              icon_bg="bg-blue-100"
              icon_color="text-blue-500"
              title="FAQ & Help Center"
              description="Common questions and guides"
              phx-click="navigate_to"
              phx-value-section="faq-help"
            />
            <.settings_menu_item
              icon="hero-lifebuoy"
              icon_bg="bg-prime-cyan-100"
              icon_color="text-prime-cyan-400"
              title="Contact Support"
              description="Get help from our team"
              phx-click="navigate_to"
              phx-value-section="contact-support"
            />
            <.settings_menu_item
              icon="hero-information-circle"
              icon_bg="bg-purple-100"
              icon_color="text-purple-500"
              title="App Information"
              description="Version, terms, privacy policy"
              phx-click="navigate_to"
              phx-value-section="app-information"
            />
            <.settings_menu_item
              icon="hero-arrow-right-on-rectangle"
              icon_bg="bg-red-100"
              icon_color="text-red-600"
              title="Sign Out"
              description="Log out of your account"
              class="hover:bg-red-50 text-red-600"
              phx-click="navigate_to"
              phx-value-section="sign-out"
            />
          </div>
        </div>
      </div>
    </div>
    """
  end
end
