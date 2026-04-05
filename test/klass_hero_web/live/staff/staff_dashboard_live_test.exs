defmodule KlassHeroWeb.Staff.StaffDashboardLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.AccountsFixtures
  import KlassHero.Factory, only: [insert: 2]
  import KlassHero.ProviderFixtures

  describe "staff dashboard" do
    setup %{conn: conn} do
      user = user_fixture(intended_roles: [:staff_provider])
      provider = provider_profile_fixture()

      staff =
        staff_member_fixture(%{
          provider_id: provider.id,
          user_id: user.id,
          active: true,
          invitation_status: :accepted,
          tags: ["sports"]
        })

      conn = log_in_user(conn, user)
      %{conn: conn, user: user, provider: provider, staff: staff}
    end

    test "renders staff dashboard with business name", %{conn: conn, provider: provider} do
      {:ok, view, _html} = live(conn, ~p"/staff/dashboard")

      assert has_element?(view, "#staff-dashboard")
      assert has_element?(view, "#business-name")
      assert render(view) =~ provider.business_name
    end

    test "shows assigned programs section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/staff/dashboard")

      assert has_element?(view, "#assigned-programs")
    end

    test "shows welcome message with staff first name", %{conn: conn, staff: staff} do
      {:ok, view, _html} = live(conn, ~p"/staff/dashboard")

      assert render(view) =~ staff.first_name
    end

    test "non-staff user is redirected", %{} do
      non_staff_user = user_fixture()
      non_staff_conn = build_conn() |> log_in_user(non_staff_user)

      assert {:error, {:redirect, %{to: "/"}}} = live(non_staff_conn, ~p"/staff/dashboard")
    end

    test "unauthenticated user is redirected", %{} do
      assert {:error, {:redirect, _}} = live(build_conn(), ~p"/staff/dashboard")
    end

    test "program cards show Sessions and Roster action buttons", %{
      conn: conn,
      provider: provider,
      staff: staff
    } do
      program =
        insert(:program_listing_schema,
          provider_id: provider.id,
          category: List.first(staff.tags) || "education"
        )

      {:ok, view, _html} = live(conn, ~p"/staff/dashboard")

      assert has_element?(view, "#sessions-link-#{program.id}")
      assert has_element?(view, "#roster-btn-#{program.id}")
    end

    test "clicking Roster opens roster modal with enrolled children", %{
      conn: conn,
      provider: provider,
      staff: staff
    } do
      program =
        insert(:program_listing_schema,
          provider_id: provider.id,
          category: List.first(staff.tags) || "education"
        )

      {:ok, view, _html} = live(conn, ~p"/staff/dashboard")

      refute has_element?(view, "#staff-roster-modal")

      view |> element("#roster-btn-#{program.id}") |> render_click()

      assert has_element?(view, "#staff-roster-modal")
      assert has_element?(view, "#staff-roster-modal", program.title)
    end

    test "closing roster modal hides it", %{conn: conn, provider: provider, staff: staff} do
      program =
        insert(:program_listing_schema,
          provider_id: provider.id,
          category: List.first(staff.tags) || "education"
        )

      {:ok, view, _html} = live(conn, ~p"/staff/dashboard")

      view |> element("#roster-btn-#{program.id}") |> render_click()
      assert has_element?(view, "#staff-roster-modal")

      view |> element("#close-roster-btn") |> render_click()
      refute has_element?(view, "#staff-roster-modal")
    end

    test "roster button rejects program not in assigned set", %{
      conn: conn,
      provider: _provider
    } do
      other_program_id = Ecto.UUID.generate()

      {:ok, view, _html} = live(conn, ~p"/staff/dashboard")

      view
      |> render_hook("view_roster", %{"id" => other_program_id})

      assert render(view) =~ "Unauthorized"
    end
  end

  describe "cross-navigation for dual-role users" do
    setup %{conn: conn} do
      %{user: user} = fixtures = KlassHero.ProviderFixtures.dual_role_user_fixture()
      Map.put(fixtures, :conn, log_in_user(conn, user))
    end

    test "shows link to provider dashboard for dual-role users", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/staff/dashboard")
      assert has_element?(view, "#cross-nav-provider-link")
    end
  end

  describe "cross-navigation for staff-only users" do
    setup %{conn: conn} do
      user = KlassHero.AccountsFixtures.user_fixture(intended_roles: [:staff_provider])
      provider = KlassHero.ProviderFixtures.provider_profile_fixture()

      staff =
        KlassHero.ProviderFixtures.staff_member_fixture(
          provider_id: provider.id,
          user_id: user.id,
          invitation_status: :accepted
        )

      conn = log_in_user(conn, user)
      %{conn: conn, user: user, staff: staff}
    end

    test "does NOT show link to provider dashboard for staff-only users", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/staff/dashboard")
      refute has_element?(view, "#cross-nav-provider-link")
    end
  end
end
