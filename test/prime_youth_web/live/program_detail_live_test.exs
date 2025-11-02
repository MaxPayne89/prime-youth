defmodule PrimeYouthWeb.ProgramDetailLiveTest do
  use PrimeYouthWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "ProgramDetailLive mount validation" do
    test "renders program detail page with valid program ID", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/programs/1")

      assert has_element?(view, "h1", "Creative Art World")
    end

    test "redirects with error flash for invalid program ID format", %{conn: conn} do
      assert {:error, {:redirect, %{to: path, flash: flash}}} = live(conn, ~p"/programs/invalid")

      assert path == ~p"/programs"
      assert flash["error"] == "Invalid program ID"
    end

    test "redirects with error flash for non-existent program ID", %{conn: conn} do
      # Using a high ID that doesn't exist in sample data
      assert {:error, {:redirect, %{to: path, flash: flash}}} = live(conn, ~p"/programs/999")

      assert path == ~p"/programs"

      assert flash["error"] ==
               "Program not found. It may have been removed or is no longer available."
    end

    test "redirects with error flash for zero program ID", %{conn: conn} do
      assert {:error, {:redirect, %{to: path, flash: flash}}} = live(conn, ~p"/programs/0")

      assert path == ~p"/programs"
      assert flash["error"] == "Invalid program ID"
    end

    test "redirects with error flash for negative program ID", %{conn: conn} do
      assert {:error, {:redirect, %{to: path, flash: flash}}} = live(conn, ~p"/programs/-1")

      assert path == ~p"/programs"
      assert flash["error"] == "Invalid program ID"
    end

    test "enroll_now button navigates to booking page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/programs/1")

      view
      |> element("button[phx-click='enroll_now']", "Book Now")
      |> render_click()

      assert_redirect(view, ~p"/programs/1/booking")
    end
  end
end
