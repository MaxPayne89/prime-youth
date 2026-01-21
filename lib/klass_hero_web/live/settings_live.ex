defmodule KlassHeroWeb.SettingsLive do
  use KlassHeroWeb, :live_view

  import KlassHeroWeb.CompositeComponents
  import KlassHeroWeb.Live.SampleFixtures

  alias KlassHeroWeb.Theme

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: gettext("Settings"))
      |> assign(user: sample_user())

    {:ok, socket}
  end

  @impl true
  def handle_event("navigate_to", %{"section" => section}, socket) do
    IO.puts("Navigate to: #{section}")
    {:noreply, socket}
  end

  attr :title, :string, required: true
  slot :inner_block, required: true

  defp settings_section(assigns) do
    ~H"""
    <div class={[
      Theme.bg(:surface),
      "shadow-sm border overflow-hidden",
      Theme.rounded(:xl),
      Theme.border_color(:light)
    ]}>
      <div class={["p-4 border-b", Theme.border_color(:light)]}>
        <h3 class={["font-semibold", Theme.text_color(:heading)]}>
          {@title}
        </h3>
      </div>
      <div>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen", Theme.bg(:muted)]}>
      <.page_header variant={:dark} size={:large} centered container_class="max-w-7xl mx-auto">
        <:title>{gettext("Settings")}</:title>
        <:subtitle>{gettext("Manage your account and preferences")}</:subtitle>
      </.page_header>

      <div class="max-w-4xl mx-auto p-4 space-y-4">
        <.settings_section title={gettext("Account & Profile")}>
          <.settings_menu_item
            icon="hero-user"
            icon_bg={Theme.bg(:primary_light)}
            icon_color={Theme.text_color(:primary)}
            title={gettext("Profile Information")}
            description={gettext("Name, email, profile photo")}
            phx-click="navigate_to"
            phx-value-section="profile-information"
          />
          <.settings_menu_item
            icon="hero-lock-closed"
            icon_bg={Theme.bg(:secondary_light)}
            icon_color={Theme.text_color(:secondary)}
            title={gettext("Privacy & Security")}
            description={gettext("Account preferences, password")}
            phx-click="navigate_to"
            phx-value-section="privacy-security"
          />
        </.settings_section>

        <.settings_section title={gettext("My Family")}>
          <.settings_menu_item
            icon="hero-user-group"
            icon_bg={Theme.bg(:primary_light)}
            icon_color={Theme.text_color(:primary)}
            title={gettext("Children Profiles")}
            description={@user.children_summary}
            phx-click="navigate_to"
            phx-value-section="children-profiles"
          />
          <.settings_menu_item
            icon="hero-calendar"
            icon_bg={Theme.bg(:secondary_light)}
            icon_color={Theme.text_color(:secondary)}
            title={gettext("My Schedule")}
            description={gettext("View all family activities")}
            phx-click="navigate_to"
            phx-value-section="my-schedule"
          />
          <.settings_menu_item
            icon="hero-badge-check"
            icon_bg={Theme.bg(:accent_light)}
            icon_color={Theme.text_color(:accent)}
            title={gettext("Family Progress")}
            description={gettext("Achievements and milestones")}
            phx-click="navigate_to"
            phx-value-section="family-progress"
          />
        </.settings_section>

        <.settings_section title={gettext("Contact Information")}>
          <.settings_menu_item
            icon="hero-home"
            icon_bg="bg-blue-100"
            icon_color="text-blue-500"
            title={gettext("Home Address")}
            description={gettext("Primary address and phone")}
            phx-click="navigate_to"
            phx-value-section="home-address"
          />
          <.settings_menu_item
            icon="hero-users"
            icon_bg="bg-purple-100"
            icon_color="text-purple-500"
            title={gettext("Parent/Guardian Details")}
            description={gettext("Contact info for both parents")}
            phx-click="navigate_to"
            phx-value-section="parent-guardian"
          />
          <.settings_menu_item
            icon="hero-exclamation-triangle"
            icon_bg="bg-red-100"
            icon_color="text-red-500"
            title={gettext("Emergency Contacts")}
            description={gettext("Backup contacts for emergencies")}
            phx-click="navigate_to"
            phx-value-section="emergency-contacts"
          />
        </.settings_section>

        <.settings_section title={gettext("Health & Safety")}>
          <.settings_menu_item
            icon="hero-heart"
            icon_bg="bg-red-100"
            icon_color="text-red-500"
            title={gettext("Medical Information")}
            description={gettext("Conditions, medications, special needs")}
            phx-click="navigate_to"
            phx-value-section="medical-information"
          />
          <.settings_menu_item
            icon="hero-exclamation-circle"
            icon_bg="bg-orange-100"
            icon_color="text-orange-500"
            title={gettext("Allergies & Dietary")}
            description={gettext("Food allergies, dietary restrictions")}
            phx-click="navigate_to"
            phx-value-section="allergies-dietary"
          />
          <.settings_menu_item
            icon="hero-shield-check"
            icon_bg="bg-green-100"
            icon_color="text-green-500"
            title={gettext("Insurance Information")}
            description={gettext("Health insurance details")}
            phx-click="navigate_to"
            phx-value-section="insurance-information"
          />
        </.settings_section>

        <.settings_section title={gettext("Permissions & Consents")}>
          <.settings_menu_item
            icon="hero-camera"
            icon_bg="bg-purple-100"
            icon_color="text-purple-500"
            title={gettext("Photo & Video Release")}
            description={gettext("Marketing and social media permissions")}
            phx-click="navigate_to"
            phx-value-section="photo-video-release"
          />
          <.settings_menu_item
            icon="hero-check-circle"
            icon_bg="bg-green-100"
            icon_color="text-green-500"
            title={gettext("Activity Permissions")}
            description={gettext("Swimming, field trips, group activities")}
            phx-click="navigate_to"
            phx-value-section="activity-permissions"
          />
          <.settings_menu_item
            icon="hero-chat-bubble-left-right"
            icon_bg={Theme.bg(:primary_light)}
            icon_color={Theme.text_color(:primary)}
            title={gettext("WhatsApp Community")}
            description={gettext("Updates, discounts, family credit")}
            phx-click="navigate_to"
            phx-value-section="whatsapp-community"
          />
        </.settings_section>

        <.settings_section title={gettext("Payment & Billing")}>
          <.settings_menu_item
            icon="hero-credit-card"
            icon_bg="bg-blue-100"
            icon_color="text-blue-500"
            title={gettext("Payment Methods")}
            description={gettext("Cards, bank accounts, billing info")}
            phx-click="navigate_to"
            phx-value-section="payment-methods"
          />
          <.settings_menu_item
            icon="hero-document-text"
            icon_bg={Theme.bg(:secondary_light)}
            icon_color={Theme.text_color(:secondary)}
            title={gettext("Transaction History")}
            description={gettext("Past payments and invoices")}
            phx-click="navigate_to"
            phx-value-section="transaction-history"
          />
          <.settings_menu_item
            icon="hero-currency-dollar"
            icon_bg={Theme.bg(:accent_light)}
            icon_color={Theme.text_color(:accent)}
            title={gettext("Family Credits & Discounts")}
            description={gettext("Available credits and promo codes")}
            phx-click="navigate_to"
            phx-value-section="family-credits"
          />
        </.settings_section>

        <.settings_section title={gettext("Notifications & Communication")}>
          <.settings_menu_item
            icon="hero-bell"
            icon_bg={Theme.bg(:primary_light)}
            icon_color={Theme.text_color(:primary)}
            title={gettext("Notification Preferences")}
            description={gettext("Push, email, SMS settings")}
            phx-click="navigate_to"
            phx-value-section="notification-preferences"
          />
          <.settings_menu_item
            icon="hero-envelope"
            icon_bg={Theme.bg(:secondary_light)}
            icon_color={Theme.text_color(:secondary)}
            title={gettext("Communication Settings")}
            description={gettext("How you want to be contacted")}
            phx-click="navigate_to"
            phx-value-section="communication-settings"
          />
        </.settings_section>

        <.settings_section title={gettext("Help & Support")}>
          <.settings_menu_item
            icon="hero-question-mark-circle"
            icon_bg="bg-blue-100"
            icon_color="text-blue-500"
            title={gettext("FAQ & Help Center")}
            description={gettext("Common questions and guides")}
            phx-click="navigate_to"
            phx-value-section="faq-help"
          />
          <.settings_menu_item
            icon="hero-lifebuoy"
            icon_bg={Theme.bg(:primary_light)}
            icon_color={Theme.text_color(:primary)}
            title={gettext("Contact Support")}
            description={gettext("Get help from our team")}
            phx-click="navigate_to"
            phx-value-section="contact-support"
          />
          <.settings_menu_item
            icon="hero-information-circle"
            icon_bg="bg-purple-100"
            icon_color="text-purple-500"
            title={gettext("App Information")}
            description={gettext("Version, terms, privacy policy")}
            phx-click="navigate_to"
            phx-value-section="app-information"
          />
          <.settings_menu_item
            icon="hero-arrow-right-on-rectangle"
            icon_bg="bg-red-100"
            icon_color="text-red-600"
            title={gettext("Sign Out")}
            description={gettext("Log out of your account")}
            class="hover:bg-red-50 text-red-600"
            phx-click="navigate_to"
            phx-value-section="sign-out"
          />
        </.settings_section>
      </div>
    </div>
    """
  end
end
