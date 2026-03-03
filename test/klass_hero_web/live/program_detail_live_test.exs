defmodule KlassHeroWeb.ProgramDetailLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import KlassHero.ProviderFixtures
  import Phoenix.LiveViewTest

  describe "ProgramDetailLive mount validation" do
    test "renders program detail page with valid program ID", %{conn: conn} do
      program = insert(:program_schema, title: "Creative Art World")
      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}")

      assert has_element?(view, "h1", "Creative Art World")
    end

    test "redirects with error flash for invalid program ID format", %{conn: conn} do
      assert {:error, {:redirect, %{to: path, flash: flash}}} = live(conn, ~p"/programs/invalid")

      assert path == ~p"/programs"

      # Invalid UUIDs return :not_found, which shows the "not found" message
      assert flash["error"] ==
               "Program not found. It may have been removed or is no longer available."
    end

    test "redirects with error flash for non-existent program ID", %{conn: conn} do
      # Use a valid UUID format that doesn't exist in database
      non_existent_uuid = "550e8400-e29b-41d4-a716-446655449999"

      assert {:error, {:redirect, %{to: path, flash: flash}}} =
               live(conn, ~p"/programs/#{non_existent_uuid}")

      assert path == ~p"/programs"

      assert flash["error"] ==
               "Program not found. It may have been removed or is no longer available."
    end

    test "redirects with error flash for zero program ID", %{conn: conn} do
      assert {:error, {:redirect, %{to: path, flash: flash}}} = live(conn, ~p"/programs/0")

      assert path == ~p"/programs"

      # Invalid UUIDs return :not_found, which shows the "not found" message
      assert flash["error"] ==
               "Program not found. It may have been removed or is no longer available."
    end

    test "redirects with error flash for negative program ID", %{conn: conn} do
      assert {:error, {:redirect, %{to: path, flash: flash}}} = live(conn, ~p"/programs/-1")

      assert path == ~p"/programs"

      # Invalid UUIDs return :not_found, which shows the "not found" message
      assert flash["error"] ==
               "Program not found. It may have been removed or is no longer available."
    end

    test "enroll_now button navigates to booking page", %{conn: conn} do
      program = insert(:program_schema)
      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}")

      view
      |> element("#book-now-button")
      |> render_click()

      assert_redirect(view, ~p"/programs/#{program.id}/booking")
    end

    test "enroll_now event shows error flash when registration is closed", %{conn: conn} do
      past_start = Date.add(Date.utc_today(), -30)
      past_end = Date.add(Date.utc_today(), -1)

      program =
        insert(:program_schema,
          registration_start_date: past_start,
          registration_end_date: past_end
        )

      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}")

      render_click(view, "enroll_now")

      assert_flash(view, :error, "Registration is not open for this program.")
    end

    test "enroll_now event shows error flash when registration is upcoming", %{conn: conn} do
      future_start = Date.add(Date.utc_today(), 7)
      future_end = Date.add(Date.utc_today(), 14)

      program =
        insert(:program_schema,
          registration_start_date: future_start,
          registration_end_date: future_end
        )

      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}")

      render_click(view, "enroll_now")

      assert_flash(view, :error, "Registration is not open for this program.")
    end

    test "back_to_programs event navigates to programs list", %{conn: conn} do
      program = insert(:program_schema)
      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}")

      view
      |> element("[phx-click='back_to_programs']")
      |> render_click()

      assert_redirect(view, ~p"/programs")
    end
  end

  describe "staff member display" do
    test "program with staff shows team member names", %{conn: conn} do
      provider = provider_profile_fixture()

      program =
        insert(:program_schema, provider_id: provider.id, title: "Soccer Academy")

      staff_member_fixture(
        provider_id: provider.id,
        first_name: "Coach",
        last_name: "Smith",
        role: "Head Coach"
      )

      {:ok, view, html} = live(conn, ~p"/programs/#{program.id}")

      assert html =~ "Coach Smith"
      assert html =~ "Head Coach"
      assert has_element?(view, "h3", "Meet Your Instructor")
    end

    test "program without staff hides instructor section", %{conn: conn} do
      program = insert(:program_schema, title: "Art Class")
      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}")

      # Trigger: no staff members for this provider (provider_id is nil)
      # Why: instructor section only renders when real team members exist
      # Outcome: neither "Meet the Team" nor "Meet Your Instructor" heading is shown
      refute has_element?(view, "h3", "Meet Your Instructor")
      refute has_element?(view, "h3", "Meet the Team")
    end

    test "staff email is not shown on public page", %{conn: conn} do
      provider = provider_profile_fixture()
      program = insert(:program_schema, provider_id: provider.id)

      staff_member_fixture(
        provider_id: provider.id,
        first_name: "Jane",
        last_name: "Doe",
        email: "jane.secret@example.com"
      )

      {:ok, _view, html} = live(conn, ~p"/programs/#{program.id}")

      # Trigger: staff email is included in presenter output
      # Why: public program pages should not expose staff email addresses
      # Outcome: email should NOT appear in rendered HTML
      refute html =~ "jane.secret@example.com"
    end
  end
end
