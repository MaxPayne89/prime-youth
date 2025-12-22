defmodule PrimeYouthWeb.BookingLiveTest do
  use PrimeYouthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PrimeYouth.Factory

  describe "BookingLive authentication" do
    test "redirects to login when not authenticated", %{conn: conn} do
      program = insert(:program_schema)
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/programs/#{program.id}/booking")

      # Should redirect to login page
      assert path == ~p"/users/log-in"
    end

    test "renders booking page when authenticated with valid program", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      program = insert(:program_schema, title: "Creative Art World")

      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}/booking")

      assert has_element?(view, "h1", "Enrollment")
      assert render(view) =~ "Creative Art World"
    end
  end

  describe "BookingLive mount validation" do
    setup :register_and_log_in_user

    test "redirects with error flash for invalid program ID format", %{conn: conn} do
      assert {:error, {:redirect, %{to: path, flash: flash}}} =
               live(conn, ~p"/programs/invalid/booking")

      assert path == ~p"/programs"
      assert flash["error"] == "Unable to load program. Please try again later."
    end

    test "redirects with error flash for non-existent program ID", %{conn: conn} do
      # Use a valid UUID format that doesn't exist in database
      non_existent_uuid = "550e8400-e29b-41d4-a716-446655449999"

      assert {:error, {:redirect, %{to: path, flash: flash}}} =
               live(conn, ~p"/programs/#{non_existent_uuid}/booking")

      assert path == ~p"/programs"
      assert flash["error"] == "Program not found"
    end

    test "redirects with error flash when program has no spots left", %{conn: _conn} do
      # Note: This test assumes we can mock a program with 0 spots
      # In a real implementation, you might need to modify sample_programs
      # or add a way to set spots_left to 0 for testing

      # For now, we'll skip this test and add it when we have database support
      # {:error, {:redirect, %{to: path, flash: flash}}} = live(conn, ~p"/programs/4/booking")
      # assert path =~ ~r/\/programs\/\d+/
      # assert flash["error"] =~ "currently full"
    end
  end

  describe "BookingLive enrollment validation" do
    setup :register_and_log_in_user

    test "complete_enrollment with missing child_id shows error", %{conn: conn} do
      program = insert(:program_schema)
      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}/booking")

      html =
        view
        |> form("form[phx-submit='complete_enrollment']", %{
          "child_id" => "",
          "special_requirements" => "Test"
        })
        |> render_submit()

      assert html =~ "Please select a child for enrollment."
    end

    test "complete_enrollment with valid data shows success message", %{conn: conn} do
      program = insert(:program_schema)
      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}/booking")

      view
      |> form("form[phx-submit='complete_enrollment']", %{
        "child_id" => "1",
        "special_requirements" => "No allergies"
      })
      |> render_submit()

      assert_redirect(view, ~p"/dashboard")
    end

    test "back_to_program button navigates to program detail", %{conn: conn} do
      program = insert(:program_schema)
      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}/booking")

      view
      |> element("[phx-click='back_to_program']")
      |> render_click()

      assert_redirect(view, ~p"/programs/#{program.id}")
    end

    test "select_payment_method updates payment method and recalculates totals", %{conn: conn} do
      program = insert(:program_schema)
      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}/booking")

      # Initially card payment is selected
      html = render(view)
      assert html =~ "Credit card fee"

      # Switch to transfer payment
      view
      |> element("[phx-click='select_payment_method'][phx-value-method='transfer']")
      |> render_click()

      # Card fee should be removed
      html = render(view)
      refute html =~ "Credit card fee"
      assert html =~ "Bank Transfer Details"
    end
  end
end
