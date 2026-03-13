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

  describe "filter mode" do
    setup :register_and_log_in_admin

    setup do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id, title: "Soccer Training")

      insert(:program_session_schema,
        program_id: program.id,
        session_date: Date.utc_today(),
        status: "completed"
      )

      %{provider: provider, program: program}
    end

    test "switches to filter mode", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/sessions")

      view |> element("#mode-filter") |> render_click()
      assert has_element?(view, "#filter-form")
    end

    test "switches back to today mode", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/sessions")

      view |> element("#mode-filter") |> render_click()
      view |> element("#mode-today") |> render_click()
      refute has_element?(view, "#filter-form")
    end
  end

  describe "correction flow" do
    setup :register_and_log_in_admin

    setup do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      user = KlassHero.AccountsFixtures.unconfirmed_user_fixture()

      session =
        insert(:program_session_schema,
          program_id: program.id,
          session_date: Date.utc_today(),
          status: "in_progress"
        )

      {child, parent} = insert_child_with_guardian(first_name: "Emma")

      record =
        insert(:participation_record_schema,
          session_id: session.id,
          child_id: child.id,
          parent_id: parent.id,
          status: :checked_in,
          check_in_at: ~U[2026-03-13 09:00:00Z],
          check_in_by: user.id
        )

      %{session: session, record: record}
    end

    test "opens correction form for a record", %{conn: conn, session: session, record: record} do
      {:ok, view, _html} = live(conn, ~p"/admin/sessions/#{session.id}")

      view |> element("#correct-#{record.id}") |> render_click()
      assert has_element?(view, "#correction-form")
    end

    test "cancels correction", %{conn: conn, session: session, record: record} do
      {:ok, view, _html} = live(conn, ~p"/admin/sessions/#{session.id}")

      view |> element("#correct-#{record.id}") |> render_click()
      view |> element("#cancel-correction") |> render_click()
      refute has_element?(view, "#correction-form")
    end

    test "saves correction with reason", %{conn: conn, session: session, record: record} do
      {:ok, view, _html} = live(conn, ~p"/admin/sessions/#{session.id}")

      view |> element("#correct-#{record.id}") |> render_click()

      view
      |> form("#correction-form", %{
        correction: %{
          status: "checked_out",
          check_out_at: "2026-03-13T10:30",
          reason: "Provider forgot to check out"
        }
      })
      |> render_submit()

      assert render(view) =~ "corrected successfully"
    end

    test "shows error when reason is blank", %{conn: conn, session: session, record: record} do
      {:ok, view, _html} = live(conn, ~p"/admin/sessions/#{session.id}")

      view |> element("#correct-#{record.id}") |> render_click()

      view
      |> form("#correction-form", %{
        correction: %{status: "absent", reason: ""}
      })
      |> render_submit()

      assert render(view) =~ "reason"
    end
  end
end
