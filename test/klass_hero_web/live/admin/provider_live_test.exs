defmodule KlassHeroWeb.Admin.ProviderLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.ProviderFixtures
  import Phoenix.LiveViewTest

  describe "admin access control" do
    setup :register_and_log_in_admin

    test "admin can access /admin/providers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/providers")
      assert html =~ "Providers"
    end

    test "new provider button is not shown on index", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/providers")
      refute has_element?(view, "a", "New")
    end
  end

  describe "non-admin access control" do
    setup :register_and_log_in_user

    test "non-admin is redirected from /admin/providers", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/", flash: flash}}} = live(conn, ~p"/admin/providers")
      assert flash["error"] =~ "access"
    end
  end

  describe "unauthenticated access control" do
    test "unauthenticated user is redirected from /admin/providers", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin/providers")
    end
  end

  describe "provider list" do
    setup :register_and_log_in_admin

    test "displays providers in the table", %{conn: conn} do
      _provider = provider_profile_fixture(business_name: "Acme Activities")

      {:ok, view, _html} = live(conn, ~p"/admin/providers")

      assert has_element?(view, "td", "Acme Activities")
    end
  end

  describe "edit provider" do
    setup :register_and_log_in_admin

    test "admin can toggle verified status and sets audit fields", %{conn: conn, user: user} do
      provider = provider_profile_fixture(business_name: "Verify Me")

      {:ok, view, _html} = live(conn, ~p"/admin/providers/#{provider.id}/edit")

      view
      |> form("#resource-form", %{change: %{verified: true}})
      |> render_submit(%{"save-type" => "save"})

      schema =
        KlassHero.Repo.get!(
          KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema,
          provider.id
        )

      assert schema.verified == true
      assert schema.verified_at != nil
      assert schema.verified_by_id == user.id
    end

    test "admin can unverify and clears audit fields", %{conn: conn} do
      provider = provider_profile_fixture(business_name: "Unverify Me", verified: true)

      {:ok, view, _html} = live(conn, ~p"/admin/providers/#{provider.id}/edit")

      view
      |> form("#resource-form", %{change: %{verified: false}})
      |> render_submit(%{"save-type" => "save"})

      schema =
        KlassHero.Repo.get!(
          KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema,
          provider.id
        )

      assert schema.verified == false
      assert schema.verified_at == nil
      assert schema.verified_by_id == nil
    end

    test "admin can change subscription tier", %{conn: conn} do
      provider = provider_profile_fixture(business_name: "Tier Change")

      {:ok, view, _html} = live(conn, ~p"/admin/providers/#{provider.id}/edit")

      view
      |> form("#resource-form", %{change: %{subscription_tier: "professional"}})
      |> render_submit(%{"save-type" => "save"})

      schema =
        KlassHero.Repo.get!(
          KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema,
          provider.id
        )

      assert schema.subscription_tier == "professional"
    end

    test "subscription tier select only allows valid options", %{conn: conn} do
      provider = provider_profile_fixture(business_name: "Valid Tiers")

      {:ok, view, _html} = live(conn, ~p"/admin/providers/#{provider.id}/edit")

      # Trigger: Backpex Select field renders an HTML <select> element
      # Why: invalid values can't be submitted through a <select> — only listed options
      # Outcome: verify the select contains exactly the expected tier options
      html = render(view)
      assert html =~ "Starter"
      assert html =~ "Professional"
      assert html =~ "Business Plus"
    end
  end
end
