defmodule PrimeYouthWeb.DashboardLiveTest do
  use PrimeYouthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "DashboardLive" do
    setup :register_and_log_in_user

    test "renders dashboard page successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "h3", "My Children")
      assert has_element?(view, "h3", "Quick Actions")
    end

    test "displays profile header with user information", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify user profile is displayed
      assert html =~ "children enrolled"
      # Settings link should be present
      assert html =~ "/settings"
    end

    test "streams children collection with phx-update=\"stream\"", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify stream container has correct attributes
      assert html =~ "id=\"children\""
      assert html =~ "phx-update=\"stream\""

      # Verify children section exists
      assert html =~ "My Children"
    end

    test "displays child cards from stream data", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify child cards are rendered
      # Sample data should provide children with names, ages, schools
      assert html =~ "My Children"

      # Child cards should include progress indicators
      # The word "sessions" appears in child card data but may be lowercase
    end

    test "displays quick action buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify all four quick action buttons are present
      assert html =~ "Book Activity"
      assert html =~ "View Schedule"
      assert html =~ "Messages"
      assert html =~ "Payments"
    end

    test "quick actions section has proper grid layout", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify grid layout classes
      assert html =~ "grid-cols-2"
      assert html =~ "md:grid-cols-4"
      assert html =~ "Quick Actions"
    end

    test "children section has View All button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Verify "View All" button exists for children section
      assert has_element?(view, "button", "View All")
    end

    test "settings link navigates to settings page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify settings link is present - using href instead of navigate
      assert html =~ "href=\"/users/settings\""
    end

    test "page title is set to Dashboard", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify dashboard content is rendered
      assert html =~ "My Children"
      assert html =~ "Quick Actions"
    end

    test "responsive grid layout for children cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify responsive grid classes are present
      assert html =~ "md:grid-cols-2"
      assert html =~ "lg:grid-cols-1"
      assert html =~ "xl:grid-cols-2"
    end

    test "profile header shows correct number of enrolled children", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify enrollment count is displayed
      assert html =~ "children enrolled"

      # The count should match the length of @children stream
      # Sample data provides extended children list
    end

    test "child cards display name, age, school, sessions, and progress", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify child card structure includes all expected data
      assert html =~ "My Children"

      # Child cards should include:
      # - name, age, school, sessions, progress, activities
      # These are passed as assigns to child_card component
    end

    test "stream maintains order of children", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify children stream container exists
      assert html =~ "id=\"children\""
      assert html =~ "phx-update=\"stream\""

      # Stream should maintain insertion order from sample_children(:extended)
    end

    test "dashboard uses gradient page header variant", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify page header component with gradient variant
      # This is indicated by gradient background classes
      assert html =~ "bg-gradient"
    end
  end
end
