defmodule KlassHeroWeb.Provider.SubscriptionLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # Factory default is :professional tier
  setup :register_and_log_in_provider

  describe "mount" do
    test "renders subscription page with all three tiers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/subscription")

      assert has_element?(view, "#subscription-page")
      assert has_element?(view, "#tier-starter")
      assert has_element?(view, "#tier-professional")
      assert has_element?(view, "#tier-business_plus")
    end

    test "marks current tier as active", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/subscription")

      assert has_element?(view, "#tier-professional [data-current-plan]")
    end
  end

  describe "switch_tier event" do
    test "upgrades to business_plus tier", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/subscription")

      view
      |> element("#switch-to-business_plus")
      |> render_click()

      assert has_element?(view, "#tier-business_plus [data-current-plan]")
      assert render(view) =~ "Switched to"
    end

    test "downgrades to starter tier", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/subscription")

      view
      |> element("#switch-to-starter")
      |> render_click()

      assert has_element?(view, "#tier-starter [data-current-plan]")
      assert render(view) =~ "Switched to"
    end

    test "switches to business_plus then back to professional", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/subscription")

      # Upgrade to business_plus
      view |> element("#switch-to-business_plus") |> render_click()
      assert has_element?(view, "#tier-business_plus [data-current-plan]")

      # Downgrade back to professional
      view |> element("#switch-to-professional") |> render_click()
      assert has_element?(view, "#tier-professional [data-current-plan]")
      assert render(view) =~ "Switched to"
    end

    test "current plan button is disabled", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/subscription")

      assert has_element?(view, "#switch-to-professional[disabled]")
      assert has_element?(view, "#switch-to-professional[data-current-plan]")
    end

    test "switching to current tier shows already-on-plan flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/subscription")

      # Bypass disabled button by sending event directly (e.g. crafted WS message)
      render_click(view, "switch_tier", %{"tier" => "professional"})

      assert render(view) =~ "already on this plan"
    end
  end
end
