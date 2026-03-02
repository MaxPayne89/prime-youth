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
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "#children[phx-update=stream]")
    end

    test "displays weekly activity goal section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "goal" or html =~ "Goal" or html =~ "activities"
    end

    test "children section has View All link to children settings", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "a[href='/settings/children']", "View All")
    end

    test "displays add child button linking to new child page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "#add-child-button")
      assert has_element?(view, "#add-child-button a[href='/settings/children/new']")
    end

    test "add child button navigates to new child page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      view
      |> element("#add-child-button a")
      |> render_click()

      assert_redirect(view, "/settings/children/new")
    end

    test "view all link navigates to children settings index", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      view
      |> element("a[href='/settings/children']", "View All")
      |> render_click()

      assert_redirect(view, "/settings/children")
    end

    test "displays My Children section heading", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "My Children"
    end

    test "children section uses horizontal scroll layout", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "overflow-x-auto"
      assert html =~ "snap-x"
    end
  end
end
