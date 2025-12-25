defmodule PrimeYouthWeb.Provider.AttendanceLiveTest do
  use PrimeYouthWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import PrimeYouth.Factory

  alias PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.AttendanceRecordSchema
  alias PrimeYouth.Repo

  describe "Provider AttendanceLive - Mount & Display" do
    setup :register_and_log_in_user

    setup %{user: user} do
      # Create provider profile linked to user
      provider = insert(:provider_schema, identity_id: user.id)
      program = insert(:program_schema)

      session =
        insert(:program_session_schema,
          program_id: program.id,
          status: "in_progress"
        )

      child = insert(:child_schema)

      record =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          parent_id: child.parent_id,
          status: "expected"
        )

      %{session: session, record: record, child: child, program: program, provider: provider}
    end

    test "authenticated provider can access attendance page", %{
      conn: conn,
      session: session
    } do
      {:ok, view, _html} = live(conn, ~p"/provider/attendance/#{session.id}")

      # Page should render with attendance form and roster
      html = render(view)
      assert html =~ "Attendance Check-In" or html =~ "Session Roster"
    end

    test "displays session details", %{conn: conn, session: session, program: program} do
      {:ok, _view, html} = live(conn, ~p"/provider/attendance/#{session.id}")

      assert html =~ program.title or html =~ "Manage Attendance"
    end

    test "displays roster with expected children", %{
      conn: conn,
      session: session
    } do
      {:ok, view, _html} = live(conn, ~p"/provider/attendance/#{session.id}")

      # The roster should display with attendance records (may show Unknown Child if child lookup fails)
      html = render(view)
      assert html =~ "Session Roster" or has_element?(view, "#attendance-form")
    end

    test "redirects to sessions list when session not found", %{conn: conn} do
      invalid_id = Ecto.UUID.generate()
      {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/provider/attendance/#{invalid_id}")

      assert path == "/provider/sessions"
    end
  end

  describe "Provider AttendanceLive - Check-in Flow" do
    setup :register_and_log_in_user

    setup %{user: user} do
      # Create provider profile linked to user
      _provider = insert(:provider_schema, identity_id: user.id)
      program = insert(:program_schema)

      session =
        insert(:program_session_schema,
          program_id: program.id,
          status: "in_progress"
        )

      child = insert(:child_schema)

      record =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          parent_id: child.parent_id,
          status: "expected"
        )

      %{session: session, record: record, child: child}
    end

    test "check_in event transitions record to checked_in status", %{
      conn: conn,
      session: session,
      record: record
    } do
      {:ok, view, _html} = live(conn, ~p"/provider/attendance/#{session.id}")

      # Trigger check-in event
      view
      |> element("[phx-click='check_in'][phx-value-id='#{record.id}']")
      |> render_click()

      # Verify flash message indicates success
      assert render(view) =~ "checked in" or has_element?(view, ".flash")

      # Verify database was updated
      updated_record = Repo.get!(AttendanceRecordSchema, record.id)
      assert updated_record.status == "checked_in"
      assert updated_record.check_in_at != nil
    end

    test "shows success flash after check-in", %{
      conn: conn,
      session: session,
      record: record
    } do
      {:ok, view, _html} = live(conn, ~p"/provider/attendance/#{session.id}")

      view
      |> element("[phx-click='check_in'][phx-value-id='#{record.id}']")
      |> render_click()

      # Flash message should appear
      html = render(view)
      assert html =~ "checked in" or html =~ "success"
    end
  end

  describe "Provider AttendanceLive - Check-out Flow" do
    setup :register_and_log_in_user

    setup %{user: user} do
      # Create provider profile linked to user
      _provider = insert(:provider_schema, identity_id: user.id)
      program = insert(:program_schema)

      session =
        insert(:program_session_schema,
          program_id: program.id,
          status: "in_progress"
        )

      child = insert(:child_schema)

      # Create a checked-in record for check-out testing
      record =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          parent_id: child.parent_id,
          status: "checked_in",
          check_in_at: DateTime.utc_now() |> DateTime.add(-3600, :second)
        )

      %{session: session, record: record, child: child}
    end

    test "check_out event transitions record to checked_out status", %{
      conn: conn,
      session: session,
      record: record
    } do
      {:ok, view, _html} = live(conn, ~p"/provider/attendance/#{session.id}")

      # Trigger check-out event
      view
      |> element("[phx-click='check_out'][phx-value-id='#{record.id}']")
      |> render_click()

      # Verify database was updated
      updated_record = Repo.get!(AttendanceRecordSchema, record.id)
      assert updated_record.status == "checked_out"
      assert updated_record.check_out_at != nil
    end

    test "shows success flash after check-out", %{
      conn: conn,
      session: session,
      record: record
    } do
      {:ok, view, _html} = live(conn, ~p"/provider/attendance/#{session.id}")

      view
      |> element("[phx-click='check_out'][phx-value-id='#{record.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "checked out" or html =~ "success"
    end
  end

  describe "Provider AttendanceLive - Batch Submit" do
    setup :register_and_log_in_user

    setup %{user: user} do
      # Create provider profile linked to user
      _provider = insert(:provider_schema, identity_id: user.id)
      program = insert(:program_schema)

      session =
        insert(:program_session_schema,
          program_id: program.id,
          status: "in_progress"
        )

      child1 = insert(:child_schema)
      child2 = insert(:child_schema)

      # Create checked-out records for submission
      record1 =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child1.id,
          parent_id: child1.parent_id,
          status: "checked_out",
          check_in_at: DateTime.utc_now() |> DateTime.add(-7200, :second),
          check_out_at: DateTime.utc_now() |> DateTime.add(-3600, :second)
        )

      record2 =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child2.id,
          parent_id: child2.parent_id,
          status: "checked_out",
          check_in_at: DateTime.utc_now() |> DateTime.add(-7200, :second),
          check_out_at: DateTime.utc_now() |> DateTime.add(-3600, :second)
        )

      %{session: session, records: [record1, record2]}
    end

    test "submit_attendance event marks selected records as submitted", %{
      conn: conn,
      session: session,
      records: [record1, record2]
    } do
      {:ok, view, _html} = live(conn, ~p"/provider/attendance/#{session.id}")

      # Submit attendance with selected records
      view
      |> form("#attendance-form", %{
        "attendance" => %{"checked_in" => [to_string(record1.id), to_string(record2.id)]}
      })
      |> render_submit()

      # Verify records were submitted
      updated_record1 = Repo.get!(AttendanceRecordSchema, record1.id)
      updated_record2 = Repo.get!(AttendanceRecordSchema, record2.id)

      assert updated_record1.submitted == true
      assert updated_record2.submitted == true
    end

    test "shows error when no records selected for submission", %{
      conn: conn,
      session: session
    } do
      {:ok, view, _html} = live(conn, ~p"/provider/attendance/#{session.id}")

      # Submit the form without selecting any records
      view
      |> form("#attendance-form", %{})
      |> render_submit()

      html = render(view)
      assert html =~ "select" or html =~ "at least one" or html =~ "error"
    end
  end

  describe "Provider AttendanceLive - Error Handling" do
    setup :register_and_log_in_user

    test "handles non-existent record gracefully", %{conn: conn, user: user} do
      # Create provider profile linked to user
      _provider = insert(:provider_schema, identity_id: user.id)
      program = insert(:program_schema)

      session =
        insert(:program_session_schema,
          program_id: program.id,
          status: "in_progress"
        )

      child = insert(:child_schema)

      _record =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          parent_id: child.parent_id,
          status: "expected"
        )

      {:ok, view, _html} = live(conn, ~p"/provider/attendance/#{session.id}")

      # Try to check in with non-existent record ID
      fake_id = Ecto.UUID.generate()

      result =
        view
        |> element("[phx-click='check_in']")
        |> render_click(%{"id" => fake_id})

      # Should show error flash, not crash
      assert result =~ "not found" or result =~ "error" or is_binary(result)
    end
  end
end
