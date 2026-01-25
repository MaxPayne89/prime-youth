defmodule KlassHeroWeb.ProgramDetailLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
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
  end
end
