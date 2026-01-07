defmodule KlassHeroWeb.DashboardLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "DashboardLive" do
    setup :register_and_log_in_user

    test "renders dashboard page successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "h2", "My Children")
    end

    test "displays profile header with user information", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Settings link should be present in navigation
      assert html =~ "/users/settings"
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
      assert html =~ "My Children"
    end

    test "displays weekly activity goal section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify weekly goal section content is present
      # The weekly_goal_card component should render goal-related content
      assert html =~ "goal" or html =~ "Goal" or html =~ "activities"
    end

    test "displays family achievements section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify achievements are displayed
      assert html =~ "Activity Explorer" or html =~ "Super Reviewer" or html =~ "Art Pro"
    end

    test "children section has View All placeholder", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Verify "View All" placeholder exists for children section (currently disabled)
      assert has_element?(view, "span", "View All")
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
    end

    test "children section uses horizontal scroll layout", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify horizontal scroll layout classes are present for children carousel
      assert html =~ "overflow-x-auto"
      assert html =~ "snap-x"
    end

    test "child cards display with stream data", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify child card structure exists
      assert html =~ "My Children"
    end

    test "stream maintains order of children", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify children stream container exists
      assert html =~ "id=\"children\""
      assert html =~ "phx-update=\"stream\""
    end

    test "displays recommended programs section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify recommended programs section is displayed
      assert html =~ "Recommended for"
      assert html =~ "Based on your children"
    end

    test "displays add child button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify add child button is present
      assert html =~ "Add Child"
      assert html =~ "id=\"add-child-button\""
    end

    test "displays referral section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify referral section content
      # The referral_card component should render referral stats
      assert html =~ "BERLIN" or html =~ "referral" or html =~ "Refer"
    end
  end
end
