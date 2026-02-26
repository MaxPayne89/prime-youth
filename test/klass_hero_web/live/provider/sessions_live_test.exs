defmodule KlassHeroWeb.Provider.SessionsLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import Phoenix.LiveViewTest

  alias KlassHero.Participation

  describe "authentication and authorization" do
    test "redirects unauthenticated users to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/provider/sessions")
      assert path =~ "/users/log-in"
    end

    test "redirects non-provider users to home", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/provider/sessions")
    end
  end

  describe "sessions page" do
    setup :register_and_log_in_provider

    test "renders page title and date selector", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/sessions")

      assert has_element?(view, "h1", "My Sessions")
      assert has_element?(view, "#date-select")
    end

    test "shows empty state when no sessions scheduled for today", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/sessions")

      refute has_element?(view, "button", "Start Session")
      refute has_element?(view, "button", "Complete Session")
      refute has_element?(view, "a", "Manage Participation")
    end

    test "shows sessions for today belonging to the provider", %{conn: conn, provider: provider} do
      program = insert(:program_schema, provider_id: provider.id)

      insert(:program_session_schema,
        program_id: program.id,
        session_date: Date.utc_today(),
        status: :scheduled
      )

      {:ok, view, _html} = live(conn, ~p"/provider/sessions")

      assert has_element?(view, "button", "Start Session")
    end

    test "does not show sessions for other providers", %{conn: conn} do
      other_provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: other_provider.id)

      insert(:program_session_schema,
        program_id: program.id,
        session_date: Date.utc_today(),
        status: :scheduled
      )

      {:ok, view, _html} = live(conn, ~p"/provider/sessions")

      refute has_element?(view, "button", "Start Session")
      refute has_element?(view, "button", "Complete Session")
      refute has_element?(view, "a", "Manage Participation")
    end

    test "shows 'Manage Participation' link for in_progress sessions", %{
      conn: conn,
      provider: provider
    } do
      program = insert(:program_schema, provider_id: provider.id)

      insert(:program_session_schema,
        program_id: program.id,
        session_date: Date.utc_today(),
        status: :in_progress
      )

      {:ok, view, _html} = live(conn, ~p"/provider/sessions")

      assert has_element?(view, "a", "Manage Participation")
      assert has_element?(view, "button", "Complete Session")
    end

    test "shows 'View Participation' link for completed sessions", %{
      conn: conn,
      provider: provider
    } do
      program = insert(:program_schema, provider_id: provider.id)

      insert(:program_session_schema,
        program_id: program.id,
        session_date: Date.utc_today(),
        status: :completed
      )

      {:ok, view, _html} = live(conn, ~p"/provider/sessions")

      assert has_element?(view, "a", "View Participation")
    end
  end

  describe "date filtering" do
    setup :register_and_log_in_provider

    test "changing date reloads sessions for that date", %{conn: conn, provider: provider} do
      program = insert(:program_schema, provider_id: provider.id)
      tomorrow = Date.add(Date.utc_today(), 1)

      insert(:program_session_schema,
        program_id: program.id,
        session_date: tomorrow,
        status: :scheduled
      )

      {:ok, view, _html} = live(conn, ~p"/provider/sessions")

      # Initially no sessions today
      refute has_element?(view, "button", "Start Session")

      # Change to tomorrow
      render_change(view, "change_date", %{"date" => Date.to_iso8601(tomorrow)})

      assert has_element?(view, "button", "Start Session")
    end

    test "invalid date format shows error flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/sessions")

      render_change(view, "change_date", %{"date" => "not-a-date"})

      assert_flash(view, :error, "Invalid date format")
    end
  end

  describe "session actions" do
    setup :register_and_log_in_provider

    test "start_session transitions scheduled session to in_progress", %{
      conn: conn,
      provider: provider
    } do
      program = insert(:program_schema, provider_id: provider.id)

      session =
        insert(:program_session_schema,
          program_id: program.id,
          session_date: Date.utc_today(),
          status: :scheduled
        )

      {:ok, view, _html} = live(conn, ~p"/provider/sessions")

      view
      |> element("button[phx-value-session_id='#{session.id}']", "Start Session")
      |> render_click()

      # Verify persistence — session transitioned in DB
      {:ok, %{session: updated}} = Participation.get_session_with_roster(session.id)
      assert updated.status == :in_progress

      assert_flash(view, :info, "Session started successfully")
    end

    test "complete_session transitions in_progress session to completed", %{
      conn: conn,
      provider: provider
    } do
      program = insert(:program_schema, provider_id: provider.id)

      session =
        insert(:program_session_schema,
          program_id: program.id,
          session_date: Date.utc_today(),
          status: :in_progress
        )

      {:ok, view, _html} = live(conn, ~p"/provider/sessions")

      view
      |> element("button[phx-value-session_id='#{session.id}']", "Complete Session")
      |> render_click()

      # Verify persistence — session transitioned in DB
      {:ok, %{session: updated}} = Participation.get_session_with_roster(session.id)
      assert updated.status == :completed

      assert_flash(view, :info, "Session completed successfully")
    end
  end
end
