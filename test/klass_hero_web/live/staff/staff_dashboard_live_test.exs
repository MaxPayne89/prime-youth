defmodule KlassHeroWeb.Staff.StaffDashboardLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.AccountsFixtures
  import KlassHero.ProviderFixtures

  describe "staff dashboard" do
    setup %{conn: conn} do
      user = user_fixture()
      provider = provider_profile_fixture()

      staff =
        staff_member_fixture(%{
          provider_id: provider.id,
          user_id: user.id,
          active: true,
          invitation_status: :accepted
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
  end
end
