defmodule KlassHeroWeb.Admin.SessionsLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import Phoenix.LiveViewTest

  describe "admin access control" do
    setup :register_and_log_in_admin

    test "admin can access /admin/sessions", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/sessions")
      assert html =~ "Sessions"
    end
  end

  describe "non-admin access" do
    setup :register_and_log_in_user

    test "non-admin is redirected", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/", flash: flash}}} =
               live(conn, ~p"/admin/sessions")

      assert flash["error"] =~ "access"
    end
  end

  describe "today mode" do
    setup :register_and_log_in_admin

    setup do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id, title: "Art Adventures")

      session =
        insert(:program_session_schema,
          program_id: program.id,
          session_date: Date.utc_today(),
          start_time: ~T[09:00:00],
          end_time: ~T[10:30:00],
          status: "in_progress"
        )

      user = KlassHero.AccountsFixtures.unconfirmed_user_fixture()
      {child, parent} = insert_child_with_guardian()

      insert(:participation_record_schema,
        session_id: session.id,
        child_id: child.id,
        parent_id: parent.id,
        status: :checked_in,
        check_in_at: DateTime.utc_now(),
        check_in_by: user.id
      )

      %{session: session, program: program, provider: provider}
    end

    test "displays today's sessions with program name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/sessions")
      assert has_element?(view, "#sessions-list")
      assert render(view) =~ "Art Adventures"
    end

    test "shows attendance count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/sessions")
      assert html =~ "1 / 1"
    end

    test "shows session status badge", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/sessions")
      assert html =~ "In Progress" or html =~ "in_progress"
    end
  end
end
