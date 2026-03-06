defmodule KlassHeroWeb.TrustSafetyLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "TrustSafetyLive" do
    test "renders trust and safety page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/trust-safety")

      assert has_element?(view, "h1", "TRUST & SAFETY")
    end
  end
end
