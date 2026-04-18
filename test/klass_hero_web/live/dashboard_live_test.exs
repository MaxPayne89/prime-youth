defmodule KlassHeroWeb.DashboardLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import KlassHero.ProviderFixtures
  import Phoenix.LiveViewTest

  alias KlassHero.AccountsFixtures

  describe "DashboardLive" do
    setup :register_and_log_in_user

    test "renders dashboard page successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "h2", "My Children")
    end

    test "displays profile header with user information", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Settings link should be present in navigation
      assert html =~ "/users/settings"
    end

    test "streams children collection with phx-update=\"stream\"", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "#children[phx-update=stream]")
    end

    test "displays weekly activity goal section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "goal" or html =~ "Goal" or html =~ "activities"
    end

    test "children section has View All link to children settings", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "a[href='/settings/children']", "View All")
    end

    test "displays add child button linking to new child page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "#add-child-button")
      assert has_element?(view, "#add-child-button a[href='/settings/children/new']")
    end

    test "add child button navigates to new child page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      view
      |> element("#add-child-button a")
      |> render_click()

      assert_redirect(view, "/settings/children/new")
    end

    test "view all link navigates to children settings index", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      view
      |> element("a[href='/settings/children']", "View All")
      |> render_click()

      assert_redirect(view, "/settings/children")
    end

    test "displays My Children section heading", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "My Children"
    end

    test "children section uses horizontal scroll layout", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "overflow-x-auto"
      assert html =~ "snap-x"
    end
  end

  describe "Contact Provider flow" do
    test "clicking contact_provider starts a conversation and navigates to it", %{conn: conn} do
      user = AccountsFixtures.user_fixture(intended_roles: [:parent])
      parent = insert(:parent_profile_schema, identity_id: user.id, subscription_tier: "active")
      owner = AccountsFixtures.user_fixture()
      provider = insert(:provider_profile_schema, identity_id: owner.id)
      program = insert(:program_schema, provider_id: provider.id)
      {child, _parent} = insert_child_with_guardian(parent: parent)

      insert(:enrollment_schema,
        parent_id: parent.id,
        program_id: program.id,
        child_id: child.id,
        status: "confirmed",
        confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      selector =
        ~s|button[phx-click="contact_provider"][phx-value-program-id="#{program.id}"]|

      assert {:error, {:live_redirect, %{to: path}}} =
               view |> element(selector) |> render_click()

      assert path =~ ~r"^/messages/[0-9a-f-]+$"
    end
  end

  describe "role-based redirect from /dashboard" do
    test "staff_provider user is redirected to /staff/dashboard", %{} do
      user = KlassHero.AccountsFixtures.user_fixture(intended_roles: [:staff_provider])
      provider = provider_profile_fixture()

      staff_member_fixture(%{
        provider_id: provider.id,
        user_id: user.id,
        active: true,
        invitation_status: :accepted
      })

      conn = build_conn() |> log_in_user(user)
      assert {:error, {:redirect, %{to: "/staff/dashboard"}}} = live(conn, ~p"/dashboard")
    end
  end
end
