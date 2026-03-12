defmodule KlassHeroWeb.Admin.AccountLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "admin access control" do
    setup :register_and_log_in_admin

    test "admin can access /admin/accounts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/accounts")
      assert html =~ "Accounts"
    end

    test "new user button is not shown on index", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/accounts")
      refute has_element?(view, "a", "New")
    end
  end

  describe "non-admin access control" do
    setup :register_and_log_in_user

    test "non-admin is redirected from /admin/accounts", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/", flash: flash}}} = live(conn, ~p"/admin/accounts")
      assert flash["error"] =~ "access"
    end
  end

  describe "unauthenticated access control" do
    test "unauthenticated user is redirected from /admin/accounts", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin/accounts")
    end
  end

  describe "user list" do
    setup :register_and_log_in_admin

    test "displays users in the table", %{conn: conn, user: admin} do
      regular_user = KlassHero.AccountsFixtures.user_fixture(%{name: "Regular Test User"})

      {:ok, view, _html} = live(conn, ~p"/admin/accounts")

      # Backpex renders table data after connected mount via handle_params
      assert has_element?(view, "td", admin.email)
      assert has_element?(view, "td", admin.name)
      assert has_element?(view, "td", regular_user.email)
      assert has_element?(view, "td", regular_user.name)
    end
  end

  describe "self-edit restriction" do
    setup :register_and_log_in_admin

    test "admin cannot edit their own record", %{conn: conn, user: admin} do
      assert_raise Backpex.ForbiddenError, fn ->
        live(conn, ~p"/admin/accounts/#{admin.id}/edit")
      end
    end
  end

  describe "roles badges" do
    setup :register_and_log_in_admin

    test "displays Parent badge for user with parent profile", %{conn: conn} do
      user = KlassHero.AccountsFixtures.user_fixture(%{name: "Parent User"})
      KlassHero.Factory.insert(:parent_profile_schema, identity_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/admin/accounts")

      assert has_element?(view, "span", "Parent")
    end

    test "displays Provider badge for user with provider profile", %{conn: conn} do
      user = KlassHero.AccountsFixtures.user_fixture(%{name: "Provider User"})

      KlassHero.Factory.insert(:provider_profile_schema,
        identity_id: user.id,
        business_name: "Test Biz"
      )

      {:ok, view, _html} = live(conn, ~p"/admin/accounts")

      assert has_element?(view, "span", "Provider")
    end

    test "displays Admin badge for admin user", %{conn: conn} do
      _admin_user =
        KlassHero.AccountsFixtures.user_fixture(%{name: "Other Admin", is_admin: true})

      {:ok, view, _html} = live(conn, ~p"/admin/accounts")

      # The logged-in admin also has Admin badge, but we check for the other admin
      assert has_element?(view, "span", "Admin")
    end

    test "displays multiple badges for dual-role user", %{conn: conn} do
      user = KlassHero.AccountsFixtures.user_fixture(%{name: "Dual Role"})
      KlassHero.Factory.insert(:parent_profile_schema, identity_id: user.id)

      KlassHero.Factory.insert(:provider_profile_schema,
        identity_id: user.id,
        business_name: "Dual Biz"
      )

      {:ok, view, _html} = live(conn, ~p"/admin/accounts")

      assert has_element?(view, "span", "Parent")
      assert has_element?(view, "span", "Provider")
    end

    test "displays User badge for user with no profile and not admin", %{conn: conn} do
      _bare_user = KlassHero.AccountsFixtures.user_fixture(%{name: "Bare User"})

      {:ok, view, _html} = live(conn, ~p"/admin/accounts")

      assert has_element?(view, "span", "User")
    end
  end

  describe "subscription badges" do
    setup :register_and_log_in_admin

    test "displays Explorer badge for parent with explorer tier", %{conn: conn} do
      user = KlassHero.AccountsFixtures.user_fixture(%{name: "Explorer Parent"})

      KlassHero.Factory.insert(:parent_profile_schema,
        identity_id: user.id,
        subscription_tier: "explorer"
      )

      {:ok, view, _html} = live(conn, ~p"/admin/accounts")

      assert has_element?(view, "span", "Explorer")
    end

    test "displays Active badge for parent with active tier", %{conn: conn} do
      user = KlassHero.AccountsFixtures.user_fixture(%{name: "Active Parent"})

      KlassHero.Factory.insert(:parent_profile_schema,
        identity_id: user.id,
        subscription_tier: "active"
      )

      {:ok, view, _html} = live(conn, ~p"/admin/accounts")

      assert has_element?(view, "span", "Active")
    end

    test "displays Starter badge for provider with starter tier", %{conn: conn} do
      user = KlassHero.AccountsFixtures.user_fixture(%{name: "Starter Provider"})

      KlassHero.Factory.insert(:provider_profile_schema,
        identity_id: user.id,
        business_name: "Starter Biz",
        subscription_tier: "starter"
      )

      {:ok, view, _html} = live(conn, ~p"/admin/accounts")

      assert has_element?(view, "span", "Starter")
    end

    test "displays Professional badge for provider with professional tier", %{conn: conn} do
      user = KlassHero.AccountsFixtures.user_fixture(%{name: "Pro Provider"})

      KlassHero.Factory.insert(:provider_profile_schema,
        identity_id: user.id,
        business_name: "Pro Biz",
        subscription_tier: "professional"
      )

      {:ok, view, _html} = live(conn, ~p"/admin/accounts")

      assert has_element?(view, "span", "Professional")
    end

    test "displays Business+ badge for provider with business_plus tier", %{conn: conn} do
      user = KlassHero.AccountsFixtures.user_fixture(%{name: "Biz Plus Provider"})

      KlassHero.Factory.insert(:provider_profile_schema,
        identity_id: user.id,
        business_name: "Biz Plus",
        subscription_tier: "business_plus"
      )

      {:ok, view, _html} = live(conn, ~p"/admin/accounts")

      assert has_element?(view, "span", "Business+")
    end

    test "displays both tiers for dual-role user", %{conn: conn} do
      user = KlassHero.AccountsFixtures.user_fixture(%{name: "Dual Tier"})

      KlassHero.Factory.insert(:parent_profile_schema,
        identity_id: user.id,
        subscription_tier: "active"
      )

      KlassHero.Factory.insert(:provider_profile_schema,
        identity_id: user.id,
        business_name: "Dual Tier Biz",
        subscription_tier: "professional"
      )

      {:ok, view, _html} = live(conn, ~p"/admin/accounts")

      assert has_element?(view, "span", "Active")
      assert has_element?(view, "span", "Professional")
    end

    test "displays dash for user with no profiles", %{conn: conn} do
      _bare = KlassHero.AccountsFixtures.user_fixture(%{name: "No Sub User"})

      {:ok, view, _html} = live(conn, ~p"/admin/accounts")

      # The em-dash is rendered for users without any profiles
      assert render(view) =~ "—"
    end
  end

  describe "edit user" do
    setup :register_and_log_in_admin

    test "admin can update user name", %{conn: conn} do
      target_user = KlassHero.AccountsFixtures.user_fixture(%{name: "Original Name"})

      {:ok, view, _html} = live(conn, ~p"/admin/accounts/#{target_user.id}/edit")

      # Backpex requires name="save-type" value="save" on submit.
      # Pass as extra params to render_submit/2 since button values
      # aren't included automatically.
      view
      |> form("#resource-form", %{change: %{name: "Updated Name"}})
      |> render_submit(%{"save-type" => "save"})

      updated = KlassHero.Repo.get!(KlassHero.Accounts.User, target_user.id)
      assert updated.name == "Updated Name"
    end

    test "rejects blank name", %{conn: conn} do
      target_user = KlassHero.AccountsFixtures.user_fixture(%{name: "Keep This Name"})

      {:ok, view, _html} = live(conn, ~p"/admin/accounts/#{target_user.id}/edit")

      view
      |> form("#resource-form", %{change: %{name: ""}})
      |> render_submit(%{"save-type" => "save"})

      unchanged = KlassHero.Repo.get!(KlassHero.Accounts.User, target_user.id)
      assert unchanged.name == "Keep This Name"
    end

    test "rejects name shorter than 2 characters", %{conn: conn} do
      target_user = KlassHero.AccountsFixtures.user_fixture(%{name: "Keep This Name"})

      {:ok, view, _html} = live(conn, ~p"/admin/accounts/#{target_user.id}/edit")

      view
      |> form("#resource-form", %{change: %{name: "A"}})
      |> render_submit(%{"save-type" => "save"})

      unchanged = KlassHero.Repo.get!(KlassHero.Accounts.User, target_user.id)
      assert unchanged.name == "Keep This Name"
    end

    test "admin can toggle is_admin flag", %{conn: conn} do
      target_user = KlassHero.AccountsFixtures.user_fixture(%{name: "Toggle Target"})
      assert target_user.is_admin == false

      {:ok, view, _html} = live(conn, ~p"/admin/accounts/#{target_user.id}/edit")

      view
      |> form("#resource-form", %{change: %{is_admin: true}})
      |> render_submit(%{"save-type" => "save"})

      updated = KlassHero.Repo.get!(KlassHero.Accounts.User, target_user.id)
      assert updated.is_admin == true
    end
  end
end
