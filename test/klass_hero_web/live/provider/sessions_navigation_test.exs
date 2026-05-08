defmodule KlassHeroWeb.Provider.SessionsNavigationTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_provider

  describe "sessions tab in dashboard navigation" do
    # Scope selectors to the in-page nav tab (the only one with
    # `data-phx-link="redirect"` and the border-b-2 underline). Phase 3 of
    # the design-handoff migration added the same /provider/sessions link
    # in the sidebar (desktop) and bottom-tab (mobile), so selecting by
    # href + text alone matches three elements now.
    test "dashboard has sessions tab linking to /provider/sessions", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      assert has_element?(
               view,
               ~s(a[href="/provider/sessions"][data-phx-link="redirect"]),
               "Sessions"
             )
    end

    test "clicking sessions tab navigates to sessions page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      view
      |> element(~s(a[href="/provider/sessions"][data-phx-link="redirect"]), "Sessions")
      |> render_click()

      assert_redirect(view, ~p"/provider/sessions")
    end
  end
end
