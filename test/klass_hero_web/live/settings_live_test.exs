defmodule KlassHeroWeb.SettingsLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import Phoenix.LiveViewTest

  describe "page access" do
    test "redirects unauthenticated users to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/settings")

      assert path =~ "/users/log-in"
    end

    test "redirects provider users to provider dashboard", %{conn: conn} do
      %{conn: conn} = register_and_log_in_provider(%{conn: conn})

      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/settings")

      assert path == ~p"/provider/dashboard"
    end

    test "renders settings page for authenticated parent user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      {:ok, view, _html} = live(conn, ~p"/settings")

      assert has_element?(view, "h1", "Settings")
    end
  end

  describe "children summary" do
    setup :register_and_log_in_user

    test "shows no children summary when user has no parent profile", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "No children yet"
    end

    test "shows children names when parent has children", %{conn: conn, user: user} do
      parent = insert(:parent_schema, identity_id: user.id)
      insert_child_with_guardian(parent: parent, first_name: "Alice")

      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "Alice"
    end
  end

  describe "settings sections" do
    setup :register_and_log_in_user

    test "renders all expected settings sections", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      assert has_element?(view, "h3", "Account & Profile")
      assert has_element?(view, "h3", "My Family")
      assert has_element?(view, "h3", "Contact Information")
      assert has_element?(view, "h3", "Health & Safety")
      assert has_element?(view, "h3", "Permissions & Consents")
    end

    test "children profiles link navigates to settings children page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      view
      |> element("a[href='/settings/children']")
      |> render_click()

      assert_redirect(view, ~p"/settings/children")
    end
  end
end
