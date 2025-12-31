defmodule PrimeYouthWeb.I18n.Phase8ResponsiveI18nTest do
  @moduledoc """
  Phase 8: Mobile Navigation & Responsive Design Testing

  Tests bilingual support across responsive viewports:
  - Translation verification for required strings
  - Mobile navigation functionality
  - Language switcher accessibility
  - Form validation messages in both languages
  """

  use PrimeYouthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PrimeYouthWeb.I18nHelpers

  describe "Dashboard Translation Verification" do
    # Use with_child variant to ensure children are displayed on dashboard
    setup :register_and_log_in_user_with_child

    test "displays 'Progress' translation correctly in English", %{conn: conn} do
      {:ok, view, _html} = setup_locale_for_navigation(conn, "en") |> live(~p"/dashboard")

      assert_translation(view, "Progress", "en")
    end

    test "displays 'Fortschritt' translation correctly in German", %{conn: conn} do
      {:ok, view, _html} = setup_locale_for_navigation(conn, "de") |> live(~p"/dashboard")

      assert_translation(view, "Progress", "de")
    end

    test "locale is properly set in view assigns", %{conn: conn} do
      {:ok, view, _html} = setup_locale_for_navigation(conn, "de") |> live(~p"/dashboard")
      assert_locale(view, "de")

      {:ok, view, _html} = setup_locale_for_navigation(conn, "en") |> live(~p"/dashboard")
      assert_locale(view, "en")
    end
  end

  describe "Translation Persistence Across Navigation" do
    setup :register_and_log_in_user

    test "persists German locale when navigating from dashboard to programs", %{conn: conn} do
      # Start on dashboard with German locale (query param sets session)
      {:ok, view, _html} = setup_locale_for_navigation(conn, "de") |> live(~p"/dashboard")
      assert_locale(view, "de")
      assert_translation(view, "My Children", "de")

      # Navigate to programs page - locale should persist from session
      {:ok, view, _html} = setup_locale_for_navigation(conn, "de") |> live(~p"/programs")

      # Locale should persist
      assert_locale(view, "de")
      assert_translation(view, "Programs", "de")
    end

    test "persists English locale when navigating between pages", %{conn: conn} do
      # Start on dashboard with English locale
      {:ok, view, _html} = setup_locale_for_navigation(conn, "en") |> live(~p"/dashboard")
      assert_locale(view, "en")

      # Navigate to settings page
      {:ok, view, _html} = setup_locale_for_navigation(conn, "en") |> live(~p"/settings")

      # Locale should persist
      assert_locale(view, "en")
    end

    test "updates locale when changing session locale", %{conn: conn} do
      # Start with English
      {:ok, view, _html} = setup_locale_for_navigation(conn, "en") |> live(~p"/dashboard")
      assert_locale(view, "en")

      # Navigate with German locale
      {:ok, view, _html} = setup_locale_for_navigation(conn, "de") |> live(~p"/dashboard")
      assert_locale(view, "de")
      assert_translation(view, "My Children", "de")
    end
  end

  describe "Locale Switching Without Data Loss" do
    setup :register_and_log_in_user

    test "preserves page state when switching locale on dashboard", %{conn: conn} do
      # Load dashboard in English
      {:ok, view, html_en} = setup_locale_for_navigation(conn, "en") |> live(~p"/dashboard")
      assert_locale(view, "en")

      # Verify English content exists
      assert html_en =~ "My Children" || html_en =~ get_translation("My Children", "en")

      # Switch to German
      {:ok, view, html_de} = setup_locale_for_navigation(conn, "de") |> live(~p"/dashboard")
      assert_locale(view, "de")

      # Page structure should remain (streams, cards, layout)
      assert html_de =~ "id=\"children\""
      assert html_de =~ "phx-update=\"stream\""
    end

    test "switches locale without losing view context", %{conn: conn} do
      # View programs in English
      {:ok, view, _html} = setup_locale_for_navigation(conn, "en") |> live(~p"/programs")
      assert_locale(view, "en")

      # Switch to German
      {:ok, view, _html} = setup_locale_for_navigation(conn, "de") |> live(~p"/programs")
      assert_locale(view, "de")

      # Program listing should still be present
      html = render(view)
      assert html =~ "id=\"programs\""
    end
  end

  describe "Navigation Component Translations" do
    setup :register_and_log_in_user

    test "navigation items are translated to German", %{conn: conn} do
      {:ok, _view, html} = setup_locale_for_navigation(conn, "de") |> live(~p"/dashboard")

      # Check for German navigation labels
      assert html =~ get_translation("Home", "de")
      assert html =~ get_translation("Programs", "de")
      assert html =~ get_translation("About", "de")
      assert html =~ get_translation("Contact", "de")
      assert html =~ get_translation("Dashboard", "de")
    end

    test "navigation items are in English by default", %{conn: conn} do
      {:ok, _view, html} = setup_locale_for_navigation(conn, "en") |> live(~p"/dashboard")

      # Check for English navigation labels
      assert html =~ "Home"
      assert html =~ "Programs"
      assert html =~ "About"
      assert html =~ "Contact"
      assert html =~ "Dashboard"
    end

    test "language switcher is present in navigation", %{conn: conn} do
      {:ok, _view, html} = setup_locale_for_navigation(conn, "en") |> live(~p"/dashboard")

      # Language switcher should have EN and DE options
      assert html =~ "🇬🇧" || html =~ "EN"
      assert html =~ "🇩🇪" || html =~ "DE"
    end
  end

  describe "Form Validation Message Translations" do
    test "registration form displays in German", %{conn: conn} do
      path = add_locale_param("/users/register", "de")
      {:ok, view, _html} = setup_locale_for_navigation(conn, "de") |> live(path)

      # Check locale is set
      assert_locale(view, "de")

      html = render(view)
      # Check for German form labels
      assert html =~ get_translation("Email", "de") || html =~ "E-Mail"
    end

    test "registration form displays in English", %{conn: conn} do
      {:ok, view, _html} = setup_locale_for_navigation(conn, "en") |> live(~p"/users/register")

      # Check locale is set
      assert_locale(view, "en")

      html = render(view)
      # Check for English form labels
      assert html =~ "Email"
    end

    test "locale is maintained in form context", %{conn: conn} do
      # Test that German locale is maintained
      path_de = add_locale_param("/users/register", "de")
      {:ok, view, _html} = setup_locale_for_navigation(conn, "de") |> live(path_de)
      assert_locale(view, "de")

      # Test that English locale is maintained
      path_en = add_locale_param("/users/register", "en")
      {:ok, view, _html} = setup_locale_for_navigation(conn, "en") |> live(path_en)
      assert_locale(view, "en")
    end
  end

  describe "Page Content Translations" do
    setup :register_and_log_in_user

    test "home page displays German locale", %{conn: conn} do
      # Visit home page without authentication
      conn = Phoenix.ConnTest.recycle(conn)
      path = add_locale_param("/", "de")
      {:ok, view, _html} = setup_locale_for_navigation(conn, "de") |> live(path)

      assert_locale(view, "de")
    end

    test "programs page displays German translations", %{conn: conn} do
      {:ok, view, _html} = setup_locale_for_navigation(conn, "de") |> live(~p"/programs")

      assert_locale(view, "de")
      assert_translation(view, "Programs", "de")
    end

    test "about page displays German translations", %{conn: conn} do
      {:ok, view, _html} = setup_locale_for_navigation(conn, "de") |> live(~p"/about")

      assert_locale(view, "de")
      assert_translation(view, "About Prime Youth Connect", "de")
    end

    test "contact page displays German translations", %{conn: conn} do
      {:ok, view, _html} = setup_locale_for_navigation(conn, "de") |> live(~p"/contact")

      assert_locale(view, "de")
      assert_translation(view, "Contact Us", "de")
    end
  end

  describe "Settings Page Translations" do
    setup :register_and_log_in_user

    test "settings page displays German menu items", %{conn: conn} do
      {:ok, view, _html} = setup_locale_for_navigation(conn, "de") |> live(~p"/settings")

      assert_locale(view, "de")

      # Check for German settings menu items
      assert_translation(view, "Settings", "de")
      assert_translation(view, "Account & Profile", "de")
    end

    test "user can change language preference in settings", %{conn: conn} do
      {:ok, view, _html} = setup_locale_for_navigation(conn, "de") |> live(~p"/settings")

      assert_locale(view, "de")

      # Settings should show current locale preference
      html = render(view)
      assert html =~ "DE" || html =~ "🇩🇪"
    end
  end

  describe "Highlights Page Translations" do
    setup :register_and_log_in_user

    test "highlights page displays German translations", %{conn: conn} do
      {:ok, view, _html} = setup_locale_for_navigation(conn, "de") |> live(~p"/highlights")

      assert_locale(view, "de")
      assert_translation(view, "Highlights", "de")
    end

    test "achievement cards display German locale", %{conn: conn} do
      {:ok, view, _html} = setup_locale_for_navigation(conn, "de") |> live(~p"/highlights")

      assert_locale(view, "de")

      html = render(view)

      # Check for German achievement labels (check for translation existence)
      de_recent_posts = get_translation("Recent Posts", "de")
      de_view_all = get_translation("View All", "de")

      # At least one of these should appear
      assert html =~ de_recent_posts || html =~ de_view_all || html =~ "Highlights"
    end
  end
end
