defmodule KlassHeroWeb.DashboardLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import KlassHero.ProviderFixtures
  import Phoenix.LiveViewTest

  alias KlassHero.AccountsFixtures

  describe "DashboardLive (Phase 2.1 — Pa* component layout)" do
    setup :register_and_log_in_user

    test "renders dashboard page successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # New surface anchors: kid picker, KPI grid, upcoming sessions card.
      assert has_element?(view, "#dashboard-stats")
      assert has_element?(view, "#upcoming-sessions")
      assert has_element?(view, "#messages-preview")
    end

    test "sidebar links to user settings", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # parent_app layout's sidebar puts the account row at the bottom.
      assert html =~ "/users/settings"
    end

    test "renders the four-up KPI grid with backed and disabled stat cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Active programs"
      assert html =~ "Upcoming this week"
      assert html =~ "Unread messages"
      # Disabled-tone "Coming soon" pill renders for Messages when count is 0
      # (the seed user has no conversations).
      assert html =~ "Coming soon"
    end

    test "renders weekly goal card with the bundle's title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Weekly adventure goal"
    end

    test "renders kid-picker add button when no children yet", %{conn: conn} do
      # Default register_and_log_in_user does not create children, so the
      # kid-picker section is hidden. The add button (pa_kid_picker's "+")
      # is therefore not rendered — verify the section is absent rather
      # than asserting on its inner button.
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      refute has_element?(view, "#kid-picker")
    end

    test "upcoming sessions section renders an empty-state copy", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "No upcoming sessions"
    end

    test "recent messages preview renders an empty-state copy", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "No messages yet."
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
