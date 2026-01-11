defmodule KlassHeroWeb.Provider.DashboardLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_provider

  describe "overview section" do
    test "renders dashboard with business name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      # Verify main heading is present (business name + Dashboard)
      assert has_element?(view, "h1")
      # Verify navigation tabs are present
      assert has_element?(view, "nav")
    end

    test "displays stat cards", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      # Verify stat card grid is present (4 stat cards in overview)
      assert has_element?(view, ".grid")
    end

    test "displays business profile card", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      # Verify business profile section exists with Edit Profile button
      assert has_element?(view, "button", "Edit Profile")
    end
  end

  describe "tab navigation" do
    test "navigates to team section via tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      # Click on Team & Profiles tab
      view |> element("a", "Team & Profiles") |> render_click()

      # Verify URL has patched to team section
      assert_patch(view, ~p"/provider/dashboard/team")
    end

    test "navigates to programs section via tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      # Click on My Programs tab
      view |> element("a", "My Programs") |> render_click()

      # Verify URL has patched to programs section
      assert_patch(view, ~p"/provider/dashboard/programs")
    end
  end

  describe "team section" do
    test "renders team section with team members", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/team")

      # Verify Add Team Member button is present
      assert has_element?(view, "button", "Add Team Member")
    end
  end

  describe "programs section" do
    test "renders programs section with table", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      # Verify programs table exists
      assert has_element?(view, "table")
      # Verify search input exists
      assert has_element?(view, "input[name=\"search\"]")
      # Verify staff filter exists
      assert has_element?(view, "select[name=\"staff_filter\"]")
    end

    test "filters programs by search query", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      # Search for "Soccer" which should match "Junior Soccer Academy" from mock data
      view |> render_change("search_programs", %{"search" => "Soccer"})

      # Verify filtered result is present
      assert has_element?(view, "td", "Junior Soccer Academy")
    end

    test "filters programs by staff selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      # Filter by staff id "1" (Coach Mike from mock data)
      view |> render_change("filter_by_staff", %{"staff_filter" => "1"})

      # Verify Coach Mike's programs are shown
      assert has_element?(view, "td", "Coach Mike")
    end
  end
end
