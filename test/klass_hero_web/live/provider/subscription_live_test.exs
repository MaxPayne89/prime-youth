defmodule KlassHeroWeb.Provider.SubscriptionLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # Override factory default to start on :starter tier for these tests
  setup %{conn: conn} do
    user = KlassHero.AccountsFixtures.user_fixture(%{intended_roles: [:provider]})

    _provider =
      KlassHero.Factory.insert(:provider_profile_schema,
        identity_id: user.id,
        subscription_tier: "starter"
      )

    scope = KlassHero.Accounts.Scope.for_user(user) |> KlassHero.Accounts.Scope.resolve_roles()

    %{conn: log_in_user(conn, user), user: user, scope: scope}
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
  end
end
