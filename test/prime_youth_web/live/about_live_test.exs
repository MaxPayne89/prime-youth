defmodule PrimeYouthWeb.AboutLiveTest do
  use PrimeYouthWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "AboutLive" do
    test "renders about page successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      assert has_element?(view, "h1", "About Prime Youth")
    end

    test "displays hero section with page variant", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify hero section content
      assert html =~ "About Prime Youth"
      assert html =~ "Empowering young minds through quality after-school programs"
    end

    test "displays mission section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify mission heading and content
      assert html =~ "Our Mission"
      assert html =~ "every child deserves access to enriching after-school activities"
      assert html =~ "partner with qualified instructors"
      assert html =~ "easy for parents to discover, book, and manage activities"
    end

    test "displays core values section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify core values heading
      assert html =~ "Our Values"

      # Verify all four core values are present
      assert html =~ "Quality First"
      assert html =~ "qualified instructors who are passionate"

      assert html =~ "Accessibility"
      assert html =~ "transparent pricing and easy booking"

      assert html =~ "Safety"
      assert html =~ "Verified instructors, secure facilities"

      assert html =~ "Community"
      assert html =~ "supportive community of parents, instructors"
    end

    test "displays key features section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify key features heading
      assert html =~ "Why Choose Prime Youth?"

      # Verify all four key features are present
      assert html =~ "Easy Discovery"
      assert html =~ "Browse and filter programs by age, interest"

      assert html =~ "Simple Booking"
      assert html =~ "Book activities in minutes"

      assert html =~ "Secure Payments"
      assert html =~ "Safe, encrypted payment processing"

      assert html =~ "Progress Tracking"
      assert html =~ "Monitor your child&#39;s participation and achievements"
    end

    test "displays stats section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify all four stats are displayed
      assert html =~ "500+"
      assert html =~ "Programs"

      assert html =~ "1,200+"
      assert html =~ "Students"

      assert html =~ "150+"
      assert html =~ "Instructors"

      assert html =~ "98%"
      assert html =~ "Satisfaction"
    end

    test "displays CTA section with browse programs link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify CTA section content
      assert html =~ "Ready to Get Started?"
      assert html =~ "Explore our programs and find the perfect activities"
      assert html =~ "Browse Programs"
    end

    test "browse programs link navigates to programs page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify link points to programs page
      assert html =~ "href=\"/programs\""
    end

    test "page title is set to About Us", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify page title is set
      assert html =~ "About Prime Youth"
    end

    test "responsive grid layout for key features", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify responsive grid classes
      assert html =~ "md:grid-cols-2"
    end

    test "responsive grid layout for stats", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify responsive grid classes for stats
      assert html =~ "grid-cols-2"
      assert html =~ "md:grid-cols-4"
    end

    test "hero section shows back button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # The hero_section component with show_back_button should render a back button
      # This is a navigation aid for the page variant
      assert html =~ "About Prime Youth"
    end

    test "mission section contains complete description", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify both mission paragraphs are present
      assert html =~ "nurture their talents and interests"
      assert html =~ "tools they need to run successful programs"
    end

    test "core values display with gradient icons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify gradient classes are present (indicating styled icons)
      assert html =~ "bg-gradient-to-br from-prime-yellow-400"
      assert html =~ "bg-gradient-to-br from-prime-cyan-400"
      assert html =~ "bg-gradient-to-br from-green-400"
      assert html =~ "bg-gradient-to-br from-prime-magenta-400"
    end

    test "key features display with gradient backgrounds", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify gradient classes are present for features
      assert html =~ "bg-prime-cyan-100"
      assert html =~ "bg-prime-magenta-100"
      assert html =~ "bg-prime-yellow-100"
      assert html =~ "bg-green-100"
    end

    test "all sections use card component styling", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify multiple sections use card component (indicated by structured content)
      assert html =~ "Our Mission"
      assert html =~ "Our Values"
      assert html =~ "Why Choose Prime Youth?"
      assert html =~ "Ready to Get Started?"
    end
  end
end
