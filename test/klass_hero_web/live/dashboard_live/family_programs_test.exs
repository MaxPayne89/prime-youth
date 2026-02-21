defmodule KlassHeroWeb.DashboardLive.FamilyProgramsTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "Family Programs section" do
    test "shows empty state when parent has no enrollments", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "#family-programs")
      assert has_element?(view, "#family-programs-empty")
      assert has_element?(view, "#family-programs-empty a[href='/programs']")
    end
  end
end
