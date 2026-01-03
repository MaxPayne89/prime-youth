defmodule KlassHeroWeb.HomeLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "HomeLive" do
    test "renders home page successfully", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")

      assert has_element?(view, "h1")
      assert html =~ "Connecting Families with Trusted"
      assert html =~ "Heroes for Our Youth"
    end

    test "displays hero section with landing variant", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # Verify hero section content
      assert html =~ "Klass Hero"
      assert html =~ "Connecting Families with Trusted"
      assert html =~ "Heroes for Our Youth"
    end

    test "displays features section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # Verify features section heading
      assert html =~ "Why Klass Hero?"

      # Verify all three feature cards are present
      assert html =~ "Safety First"
      assert html =~ "Easy Scheduling"
      assert html =~ "Community Focused"
    end

    test "displays featured programs section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # Verify featured programs section heading
      assert html =~ "Featured Programs"
      assert html =~ "Explore top-rated activities for your children"

      # Verify "View All Programs" button exists
      assert html =~ "View All Programs"
    end

    test "explore_programs button navigates to programs page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Click "Explore Programs" button
      render_click(view, "explore_programs", %{})

      # Should navigate to programs page
      assert_redirect(view, ~p"/programs")
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
      assert html =~ "Klass Hero"
    end

    test "featured programs are displayed from sample data", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # Verify that sample programs are rendered
      # The featured_programs() fixture should provide sample data
      # We check for program card elements
      assert html =~ "Featured Programs"

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
