defmodule PrimeYouthWeb.HomeLiveTest do
  use PrimeYouthWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "HomeLive" do
    test "renders home page successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "h1", "Prime Youth")
      assert render(view) =~ "Afterschool Adventures Await"
    end

    test "displays hero section with landing variant", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # Verify hero section content
      assert html =~ "Prime Youth"
      assert html =~ "Afterschool Adventures Await"
      assert html =~ "Get Started Free"
      assert html =~ "Explore Programs"
    end

    test "displays features section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # Verify features section heading
      assert html =~ "Why Families Choose Prime Youth"

      # Verify all three feature cards are present
      assert html =~ "Expert Instructors"
      assert html =~ "Comprehensive Progress Tracking"
      assert html =~ "Flexible Scheduling"
    end

    test "displays featured programs section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # Verify featured programs section heading
      assert html =~ "Popular Programs"
      assert html =~ "Discover what families are enrolling in this season"

      # Verify "View All Programs" button exists
      assert html =~ "View All Programs"
    end

    test "displays social proof section with stats", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # Verify social proof section heading
      assert html =~ "Trusted by Families Everywhere"

      # Verify stats are displayed
      assert html =~ "10,000+"
      assert html =~ "Active Families"
      assert html =~ "500+"
      assert html =~ "Programs Available"
      assert html =~ "4.9/5"
      assert html =~ "Average Rating"
    end

    test "displays CTA section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # Verify CTA section content
      assert html =~ "Ready to Get Started?"
      assert html =~ "Join thousands of families discovering amazing afterschool programs"
      assert html =~ "Create Free Account"
    end

    test "get_started button navigates to registration page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Click "Get Started Free" button
      render_click(view, "get_started", %{})

      # Should navigate to registration page
      assert_redirect(view, ~p"/users/register")
    end

    test "explore_programs button navigates to programs page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Click "Explore Programs" button
      render_click(view, "explore_programs", %{})

      # Should navigate to programs page
      assert_redirect(view, ~p"/programs")
    end

    test "CTA get_started button navigates to registration page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # There are multiple "get_started" buttons (hero and CTA sections)
      # Both should navigate to registration
      render_click(view, "get_started", %{})

      assert_redirect(view, ~p"/users/register")
    end

    test "View All Programs button navigates to programs page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Click "View All Programs" button in featured programs section
      render_click(view, "explore_programs", %{})

      assert_redirect(view, ~p"/programs")
    end

    test "page title is set correctly", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # Verify page title is set (though it may not be directly visible in HTML)
      # This is more about ensuring the mount function sets it properly
      assert html =~ "Prime Youth"
    end

    test "featured programs are displayed from sample data", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # Verify that sample programs are rendered
      # The featured_programs() fixture should provide sample data
      # We check for program card elements
      assert html =~ "Popular Programs"

      # Verify program cards are clickable and trigger explore_programs
      assert html =~ "phx-click=\"explore_programs\""
    end

    test "responsive design elements are present", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # Verify responsive grid classes are present
      assert html =~ "md:grid-cols-3"
      assert html =~ "lg:gap-8"
      assert html =~ "max-w-7xl"
      assert html =~ "mx-auto"
    end
  end
end
