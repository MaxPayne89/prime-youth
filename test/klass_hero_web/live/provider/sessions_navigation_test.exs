defmodule KlassHeroWeb.Provider.SessionsNavigationTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_provider

  describe "sessions tab in dashboard navigation" do
    test "dashboard has sessions tab linking to /provider/sessions", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      assert has_element?(view, ~s(a[href="/provider/sessions"]), "Sessions")
    end

    test "clicking sessions tab navigates to sessions page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      view
      |> element(~s(a[href="/provider/sessions"]), "Sessions")
      |> render_click()

      assert_redirect(view, ~p"/provider/sessions")
    end
  end
end
