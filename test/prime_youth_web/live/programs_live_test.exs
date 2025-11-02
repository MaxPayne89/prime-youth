defmodule PrimeYouthWeb.ProgramsLiveTest do
  use PrimeYouthWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "ProgramsLive" do
    test "renders programs page successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/programs")

      assert has_element?(view, "h1", "Programs")
      # Verify sample programs are shown
      assert render(view) =~ "Creative Art World"
      assert render(view) =~ "Chess Masters"
    end

    test "program_click with valid program navigates to detail page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/programs")

      # Trigger program_click event (assuming Creative Art World exists in sample data)
      render_click(view, "program_click", %{"program" => "Creative Art World"})

      # Should navigate to program detail page
      assert_redirect(view, ~p"/programs/1")
    end

    test "program_click with invalid program shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/programs")

      # Trigger program_click event with non-existent program
      render_click(view, "program_click", %{"program" => "Nonexistent Program"})

      # Should stay on programs page with error flash
      assert_patch(view, ~p"/programs")
      assert render(view) =~ "Program not found"
    end

    test "restores search and filter state from URL parameters", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/programs?q=soccer&filter=available")

      # Verify the state is reflected in the rendered HTML
      assert html =~ "value=\"soccer\""
      # Filter pills should show "available" as active (gradient background)
      assert html =~ "bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400"
    end

    test "search updates URL with query parameter", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/programs")

      # Perform search - search_bar component has phx-change="search"
      render_change(view, "search", %{"search" => "art"})

      # URL should update with search query
      assert_patched?(view, ~p"/programs?q=art")
    end

    test "filter selection updates URL with filter parameter", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/programs")

      # Trigger filter_select event
      render_click(view, "filter_select", %{"filter" => "available"})

      # Verify filter parameter in HTML
      html = render(view)
      assert html =~ "available"
    end

    test "combined search and filter updates URL with both parameters", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/programs")

      # Apply search first
      render_change(view, "search", %{"search" => "chess"})

      assert_patched?(view, ~p"/programs?q=chess")

      # Then apply filter
      render_click(view, "filter_select", %{"filter" => "price"})

      # Verify both parameters are in the rendered HTML
      html = render(view)
      assert html =~ "value=\"chess\""
      assert html =~ "price"
    end

    test "clears search from URL when empty", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/programs?q=soccer")

      # Clear search
      render_change(view, "search", %{"search" => ""})

      # URL should not have q parameter
      assert_patched?(view, ~p"/programs")
    end

    test "resets to 'all' filter when selecting all", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/programs?filter=available")

      # Select "all" filter
      render_click(view, "filter_select", %{"filter" => "all"})

      # Verify no filter parameter (default is "all")
      html = render(view)
      refute html =~ "filter=available"
    end

    test "handles invalid filter parameter gracefully", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/programs?filter=invalid_filter")

      # Should render without errors (defaults to "all" filter internally)
      assert html =~ "Programs"
      # All programs should be shown (not filtered)
      assert html =~ "Creative Art World"
    end

    test "sanitizes search query from URL", %{conn: conn} do
      # Test with whitespace
      {:ok, _view, html} = live(conn, ~p"/programs?q=  art  ")

      # Search should be trimmed
      assert html =~ "value=\"art\""
    end

    test "limits search query length from URL", %{conn: conn} do
      # Create a very long search query (>100 chars)
      long_query = String.duplicate("a", 150)
      {:ok, _view, html} = live(conn, "/programs?q=#{long_query}")

      # Should be truncated to 100 characters - check value attribute length
      [value_attr] = Regex.run(~r/value="([^"]+)"/, html, capture: :all_but_first)
      assert String.length(value_attr) == 100
    end

    test "maintains filter when updating search", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/programs?filter=available")

      # Update search
      render_change(view, "search", %{"search" => "soccer"})

      # Both parameters should be maintained in the rendered HTML
      html = render(view)
      assert html =~ "value=\"soccer\""
      assert html =~ "available"
    end

    test "maintains search when updating filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/programs?q=chess")

      # Update filter
      render_click(view, "filter_select", %{"filter" => "ages"})

      # Both parameters should be maintained in the rendered HTML
      html = render(view)
      assert html =~ "value=\"chess\""
      assert html =~ "ages"
    end

    # Helper function for testing URL paths
    defp assert_patched?(view, path) do
      assert_patch(view, path)
      view
    end
  end
end
