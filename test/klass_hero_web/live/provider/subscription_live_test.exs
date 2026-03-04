defmodule KlassHeroWeb.Provider.SubscriptionLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KlassHero.AccountsFixtures
  alias KlassHero.Factory

  # Override factory default to start on :starter tier for these tests
  setup %{conn: conn} do
    user = AccountsFixtures.user_fixture(%{intended_roles: [:provider]})

    _provider =
      Factory.insert(:provider_profile_schema,
        identity_id: user.id,
        subscription_tier: "starter"
      )

    %{conn: log_in_user(conn, user), user: user}
  end

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

      # Default tier is starter (overridden in setup)
      assert has_element?(view, "#tier-starter [data-current-plan]")
    end
  end

  describe "switch_tier event" do
    test "switches to professional tier", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/subscription")

      view
      |> element("#switch-to-professional")
      |> render_click()

      assert has_element?(view, "#tier-professional [data-current-plan]")
      assert render(view) =~ "Switched to"
    end

    test "switches to business_plus tier", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/subscription")

      view
      |> element("#switch-to-business_plus")
      |> render_click()

      assert has_element?(view, "#tier-business_plus [data-current-plan]")
    end

    test "downgrades from professional to starter", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/subscription")

      # First upgrade to professional
      view |> element("#switch-to-professional") |> render_click()
      assert has_element?(view, "#tier-professional [data-current-plan]")

      # Then downgrade back to starter
      view |> element("#switch-to-starter") |> render_click()
      assert has_element?(view, "#tier-starter [data-current-plan]")
      assert render(view) =~ "Switched to"
    end

    test "current plan button is disabled", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/subscription")

      assert has_element?(view, "#switch-to-starter[disabled]")
      assert has_element?(view, "#switch-to-starter[data-current-plan]")
    end
  end
end
