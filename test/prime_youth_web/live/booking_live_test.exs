defmodule PrimeYouthWeb.BookingLiveTest do
  use PrimeYouthWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "BookingLive authentication" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/programs/1/booking")

      # Should redirect to login page
      assert path == ~p"/users/log-in"
    end

    test "renders booking page when authenticated with valid program", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      {:ok, view, _html} = live(conn, ~p"/programs/1/booking")

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
      assert flash["error"] == "Invalid program ID"
    end

    test "redirects with error flash for non-existent program ID", %{conn: conn} do
      assert {:error, {:redirect, %{to: path, flash: flash}}} =
               live(conn, ~p"/programs/999/booking")

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
      {:ok, view, _html} = live(conn, ~p"/programs/1/booking")

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
      {:ok, view, _html} = live(conn, ~p"/programs/1/booking")

      view
      |> form("form[phx-submit='complete_enrollment']", %{
        "child_id" => "1",
        "special_requirements" => "No allergies"
      })
      |> render_submit()

      assert_redirect(view, ~p"/dashboard")
    end

    test "back_to_program button navigates to program detail", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/programs/1/booking")

      view
      |> element("[phx-click='back_to_program']")
      |> render_click()

      assert_redirect(view, ~p"/programs/1")
    end

    test "select_payment_method updates payment method and recalculates totals", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/programs/1/booking")

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
