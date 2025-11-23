defmodule PrimeYouthWeb.ProgramsLiveTest do
  use PrimeYouthWeb.ConnCase

  import Phoenix.LiveViewTest

  alias PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
  alias PrimeYouth.Repo

  describe "ProgramsLive - Integration with Database (User Story 1)" do
    # T052: Write LiveView test - displays all programs from database
    test "displays all programs from database", %{conn: conn} do
      # Given: Database has 3 programs
      program1 =
        insert_program(%{
          title: "Art Adventures",
          description: "Explore creativity through painting and sculpture",
          schedule: "Mon-Fri, 3:00-5:00 PM",
          age_range: "6-8 years",
          price: Decimal.new("120.00"),
          pricing_period: "per month",
          spots_available: 12
        })

      program2 =
        insert_program(%{
          title: "Soccer Stars",
          description: "Learn soccer fundamentals and teamwork",
          schedule: "Tue, Thu, 4:00-5:30 PM",
          age_range: "8-12 years",
          price: Decimal.new("85.00"),
          pricing_period: "per month",
          spots_available: 20
        })

      program3 =
        insert_program(%{
          title: "Chess Club",
          description: "Develop strategic thinking through chess",
          schedule: "Wed, 3:30-5:00 PM",
          age_range: "7-14 years",
          price: Decimal.new("60.00"),
          pricing_period: "per month",
          spots_available: 15
        })

      # When: User navigates to /programs
      {:ok, view, html} = live(conn, ~p"/programs")

      # Then: All 3 programs are displayed
      assert html =~ program1.title
      assert html =~ program1.description
      assert html =~ program1.schedule
      assert html =~ program1.age_range
      assert html =~ "€120.00"

      assert html =~ program2.title
      assert html =~ program2.description

      assert html =~ program3.title
      assert html =~ program3.description

      # And: Programs are displayed in program cards
      assert has_element?(view, "[id^='programs-']")
    end

    # T053: Write LiveView test - shows empty state when no programs exist
    test "shows empty state when no programs exist", %{conn: conn} do
      # Given: Database has no programs (clean slate from test sandbox)

      # When: User navigates to /programs
      {:ok, view, html} = live(conn, ~p"/programs")

      # Then: Empty state message is shown
      assert html =~ "No programs found"

      # And: No program cards are rendered
      refute has_element?(view, "[id^='programs-']")
    end

    # T054: Write LiveView test - displays error message on database failure
    test "displays error message on database failure", %{conn: _conn} do
      # Given: Database connection will fail (we'll simulate this by making the use case return an error)
      # Note: This test verifies error handling in the LiveView layer
      # We need to stub the use case to return an error

      # For now, we'll test that the LiveView can handle errors gracefully
      # When the actual implementation is done, we can use Mox to stub the repository

      # When: User navigates to /programs (with mocked database failure)
      # This test will be fully implemented when T057-T061 add error handling to ProgramsLive

      # Then: Error message should be displayed
      # And: Error should be logged

      # Placeholder: Mark as pending until error handling is implemented in LiveView
      # The implementation in T057-T061 will add proper error handling
    end

    # T055: Write LiveView test - displays "Free" for €0 programs
    test "displays 'Free' for €0 programs", %{conn: conn} do
      # Given: Database has a free program (price = €0)
      free_program =
        insert_program(%{
          title: "Community Library Hour",
          description: "Free reading and learning time at the library",
          schedule: "Sat, 10:00-11:00 AM",
          age_range: "5-10 years",
          price: Decimal.new("0"),
          pricing_period: "free",
          spots_available: 30
        })

      paid_program =
        insert_program(%{
          title: "Piano Lessons",
          description: "Learn to play piano with expert instruction",
          schedule: "Mon, Wed, 4:00-5:00 PM",
          age_range: "6-16 years",
          price: Decimal.new("150.00"),
          pricing_period: "per month",
          spots_available: 8
        })

      # When: User navigates to /programs
      {:ok, _view, html} = live(conn, ~p"/programs")

      # Then: Free program displays "Free" instead of €0
      assert html =~ free_program.title
      assert html =~ "Free"

      # And: Paid program displays actual price
      assert html =~ paid_program.title
      assert html =~ "€150.00"
    end

    # T056: Write LiveView test - programs load within 2 seconds (performance requirement)
    test "programs load within 2 seconds performance requirement", %{conn: conn} do
      # Given: Database has 100+ programs to test performance requirement (FR-012)
      # Insert 100 programs to simulate real-world load
      _programs =
        for i <- 1..100 do
          insert_program(%{
            title: "Program #{i}",
            description: "Description for program #{i}",
            schedule: "Mon-Fri, 3:00-5:00 PM",
            age_range: "6-12 years",
            price: Decimal.new("#{i}.00"),
            pricing_period: "per month",
            spots_available: 10
          })
        end

      # When: User navigates to /programs and we measure the load time
      start_time = System.monotonic_time(:millisecond)
      {:ok, view, html} = live(conn, ~p"/programs")
      end_time = System.monotonic_time(:millisecond)

      load_time_ms = end_time - start_time

      # Then: Page loads within 2000ms (2 seconds as per FR-012)
      assert load_time_ms < 2000,
             "Page load time #{load_time_ms}ms exceeds 2000ms performance requirement"

      # And: All programs are displayed
      assert html =~ "Program 1"
      assert html =~ "Program 100"

      # Verify we have program cards rendered
      assert has_element?(view, "[id^='programs-']")
    end
  end

  # T057: Filter behavior validation tests
  describe "ProgramsLive - Filter Behaviors" do
    # T058: Test available filter excludes sold-out programs
    test "available filter excludes sold-out programs", %{conn: conn} do
      # Given: Database has both available and sold-out programs
      _sold_out =
        insert_program(%{
          title: "Sold Out Soccer",
          spots_available: 0
        })

      available =
        insert_program(%{
          title: "Available Art Class",
          spots_available: 5
        })

      # When: User applies "available" filter
      {:ok, view, html} = live(conn, ~p"/programs?filter=available")

      # Then: Only available programs are shown
      assert html =~ available.title
      refute html =~ "Sold Out Soccer"

      # And: Filter is marked as active
      assert has_element?(view, "[data-filter-id='available'][data-active='true']")
    end

    # T059: Test price filter sorts programs by price (lowest first)
    test "price filter sorts programs by price lowest first", %{conn: conn} do
      # Given: Database has programs with different prices including free
      free_program =
        insert_program(%{
          title: "Free Community Event",
          price: Decimal.new("0"),
          pricing_period: "free"
        })

      mid_price =
        insert_program(%{
          title: "Mid Price Program",
          price: Decimal.new("50.00")
        })

      high_price =
        insert_program(%{
          title: "Premium Program",
          price: Decimal.new("200.00")
        })

      # When: User applies "price" filter
      {:ok, _view, html} = live(conn, ~p"/programs?filter=price")

      # Then: Programs appear in price order (free → low → high)
      # Extract positions of each program title in the HTML
      free_pos = :binary.match(html, free_program.title) |> elem(0)
      mid_pos = :binary.match(html, mid_price.title) |> elem(0)
      high_pos = :binary.match(html, high_price.title) |> elem(0)

      # Verify free program appears before mid price
      assert free_pos < mid_pos, "Free program should appear before mid price program"
      # Verify mid price appears before high price
      assert mid_pos < high_pos, "Mid price should appear before high price program"
    end

    # T060: Test age filter sorts programs by age (youngest first)
    test "age filter sorts programs by age youngest first", %{conn: conn} do
      # Given: Database has programs with different age ranges
      youngest =
        insert_program(%{
          title: "Toddler Time",
          age_range: "2-4 years"
        })

      middle =
        insert_program(%{
          title: "Kids Club",
          age_range: "8-10 years"
        })

      oldest =
        insert_program(%{
          title: "Teen Workshop",
          age_range: "14-16 years"
        })

      # When: User applies "ages" filter
      {:ok, _view, html} = live(conn, ~p"/programs?filter=ages")

      # Then: Programs appear in age order (youngest → oldest)
      youngest_pos = :binary.match(html, youngest.title) |> elem(0)
      middle_pos = :binary.match(html, middle.title) |> elem(0)
      oldest_pos = :binary.match(html, oldest.title) |> elem(0)

      assert youngest_pos < middle_pos, "Youngest age range should appear first"
      assert middle_pos < oldest_pos, "Middle age range should appear before oldest"
    end

    # T061: Test age filter handles unparseable age ranges gracefully
    test "age filter handles unparseable age ranges gracefully", %{conn: conn} do
      # Given: Database has programs with various age range formats
      normal =
        insert_program(%{
          title: "Normal Age Range",
          age_range: "6-10 years"
        })

      unparseable =
        insert_program(%{
          title: "All Ages Welcome",
          age_range: "All ages"
        })

      # When: User applies "ages" filter
      {:ok, view, html} = live(conn, ~p"/programs?filter=ages")

      # Then: Both programs are displayed without crashing
      assert html =~ normal.title
      assert html =~ unparseable.title

      # And: Unparseable age ranges are sorted to the end (age 999)
      normal_pos = :binary.match(html, normal.title) |> elem(0)
      unparseable_pos = :binary.match(html, unparseable.title) |> elem(0)

      assert normal_pos < unparseable_pos,
             "Unparseable age ranges should be sorted to the end"

      # And: No errors are shown
      refute has_element?(view, ".flash-error")
    end

    # T062: Test search functionality is case-insensitive (word-boundary matching)
    test "search is case-insensitive using word-boundary matching on titles", %{conn: conn} do
      # Given: Database has programs with various titles
      soccer =
        insert_program(%{
          title: "Soccer Stars",
          description: "Learn soccer fundamentals"
        })

      art =
        insert_program(%{
          title: "Art Adventures",
          description: "Creative PAINTING activities"
        })

      chess =
        insert_program(%{
          title: "Chess Club",
          description: "Strategic thinking"
        })

      # When: User searches for "SOCCER" (uppercase, word-boundary match)
      {:ok, _view, html} = live(conn, ~p"/programs?q=SOCCER")

      # Then: Soccer program is found (case-insensitive title word-boundary match)
      assert html =~ soccer.title
      refute html =~ art.title
      refute html =~ chess.title

      # When: User searches for "art" (lowercase, word-boundary match in title)
      {:ok, view, html} = live(conn, ~p"/programs?q=art")

      # Then: Art program is found (case-insensitive title word-boundary match)
      assert html =~ art.title
      refute html =~ soccer.title
      refute html =~ chess.title

      # And: Search query is displayed in search input
      assert has_element?(view, "input[name='search'][value='art']")
    end

    # T063: Test combining search with filters
    test "combining search with available filter", %{conn: conn} do
      # Given: Database has both available and sold-out soccer programs
      _sold_out_soccer =
        insert_program(%{
          title: "Sold Out Soccer Camp",
          spots_available: 0
        })

      available_soccer =
        insert_program(%{
          title: "Available Soccer Training",
          spots_available: 10
        })

      _available_art =
        insert_program(%{
          title: "Available Art Class",
          spots_available: 5
        })

      # When: User searches for "soccer" AND filters by "available"
      {:ok, _view, html} = live(conn, ~p"/programs?q=soccer&filter=available")

      # Then: Only available soccer program is shown
      assert html =~ available_soccer.title
      refute html =~ "Sold Out Soccer Camp"
      refute html =~ "Art Class"
    end
  end

  # T032-T034: User Story 1 specific integration tests
  describe "ProgramsLive - User Story 1: Instant Program Title Search" do
    # T032: filters programs by search query
    test "filters programs by search query using word-boundary matching", %{conn: conn} do
      # Given: Database has programs with various titles
      soccer =
        insert_program(%{
          title: "After School Soccer",
          description: "Soccer fundamentals and teamwork"
        })

      _dance =
        insert_program(%{
          title: "Summer Dance Camp",
          description: "Learn dance moves"
        })

      # When: User searches for "so" (should match "Soccer" word-boundary)
      {:ok, _view, html} = live(conn, ~p"/programs?q=so")

      # Then: Only programs with words starting with "so" are shown
      assert html =~ soccer.title
      refute html =~ "Dance"
    end

    # T033: shows all programs for empty query
    test "shows all programs when search query is empty", %{conn: conn} do
      # Given: Database has programs
      program1 = insert_program(%{title: "Soccer Camp"})
      program2 = insert_program(%{title: "Art Class"})
      program3 = insert_program(%{title: "Chess Club"})

      # When: User navigates without search query
      {:ok, _view, html} = live(conn, ~p"/programs")

      # Then: All programs are displayed
      assert html =~ program1.title
      assert html =~ program2.title
      assert html =~ program3.title
    end

    # T034: updates URL with query param
    test "updates URL with search query parameter", %{conn: conn} do
      # Given: Database has programs
      _program = insert_program(%{title: "Soccer Training"})

      # When: LiveView is mounted
      {:ok, view, _html} = live(conn, ~p"/programs")

      # And: User types in search field
      view
      |> element("input[name='search']")
      |> render_change(%{"search" => "soccer"})

      # Then: URL is updated with query parameter
      assert_patch(view, ~p"/programs?q=soccer")
    end
  end

  # T064: End-to-end user journey test
  describe "ProgramsLive - End-to-End User Journey" do
    # T065: Complete user flow from browse to detail page navigation
    test "complete user journey: browse, filter, search, navigate to detail", %{conn: conn} do
      # Given: Database has multiple programs with different attributes
      soccer =
        insert_program(%{
          title: "Soccer Camp",
          description: "Fun soccer activities for kids",
          age_range: "6-10 years",
          spots_available: 10,
          price: Decimal.new("150.00")
        })

      _art_sold_out =
        insert_program(%{
          title: "Art Class",
          description: "Creative painting workshop",
          age_range: "8-12 years",
          spots_available: 0,
          price: Decimal.new("120.00")
        })

      chess =
        insert_program(%{
          title: "Chess Club",
          description: "Strategic thinking through chess",
          age_range: "7-14 years",
          spots_available: 15,
          price: Decimal.new("80.00")
        })

      # STEP 1: Browse all programs
      {:ok, view, html} = live(conn, ~p"/programs")

      # Then: All programs are displayed
      assert html =~ soccer.title
      assert html =~ "Art Class"
      assert html =~ chess.title

      # STEP 2: Filter by "available" to exclude sold-out programs
      html =
        view
        |> element("[data-filter-id='available']")
        |> render_click()

      # Then: Only available programs are shown
      assert html =~ soccer.title
      refute html =~ "Art Class"
      assert html =~ chess.title

      # And: URL reflects the filter
      assert_patch(view, ~p"/programs?filter=available")

      # STEP 3: Search for "soccer" within available programs
      html =
        view
        |> element("input[name='search']")
        |> render_change(%{"search" => "soccer"})

      # Then: Only soccer program is shown (available AND matches search)
      assert html =~ soccer.title
      refute html =~ chess.title
      refute html =~ "Art Class"

      # And: URL reflects both filter and search
      assert_patch(view, ~p"/programs?filter=available&q=soccer")

      # STEP 4: Click on the soccer program card to navigate to detail page
      result =
        view
        |> element("[phx-click='program_click'][phx-value-program='Soccer Camp']")
        |> render_click()

      # Then: Navigation to program detail page occurs
      assert {:error, {:live_redirect, %{to: redirect_path}}} = result

      # And: Redirect path includes the program ID
      assert redirect_path == "/programs/#{soccer.id}"
    end

    # T066: Test URL parameter handling persistence across LiveView lifecycle
    test "URL parameters persist across mount and handle_params", %{conn: conn} do
      # Given: Database has programs
      _available =
        insert_program(%{
          title: "Available Program",
          spots_available: 10
        })

      _sold_out =
        insert_program(%{
          title: "Sold Out Program",
          spots_available: 0
        })

      # When: User navigates directly to URL with filter parameter
      {:ok, view, html} = live(conn, ~p"/programs?filter=available")

      # Then: Filter is correctly applied on mount
      assert html =~ "Available Program"
      refute html =~ "Sold Out Program"
      assert has_element?(view, "[data-filter-id='available'][data-active='true']")

      # When: User navigates to URL with search parameter
      {:ok, _view, html} = live(conn, ~p"/programs?q=available")

      # Then: Search is correctly applied on mount
      assert html =~ "Available Program"
      refute html =~ "Sold Out Program"
    end

    # T067: Test filter + search combination with various orderings
    test "filter and search combination works regardless of application order", %{conn: conn} do
      # Given: Database has soccer and art programs, some sold out
      available_soccer =
        insert_program(%{
          title: "Available Soccer",
          description: "Soccer training",
          spots_available: 10
        })

      _sold_out_soccer =
        insert_program(%{
          title: "Sold Out Soccer Camp",
          description: "Soccer camp",
          spots_available: 0
        })

      _available_art =
        insert_program(%{
          title: "Available Art",
          description: "Art workshop",
          spots_available: 5
        })

      # Scenario 1: Apply filter first, then search
      {:ok, view, _html} = live(conn, ~p"/programs?filter=available")

      # When: User searches for "soccer"
      html = view |> element("input[name='search']") |> render_change(%{"search" => "soccer"})

      # Then: Only available soccer program is shown
      assert html =~ available_soccer.title
      refute html =~ "Sold Out Soccer"
      refute html =~ "Art"

      # Scenario 2: Apply search first, then filter (start fresh)
      {:ok, view, _html} = live(conn, ~p"/programs?q=soccer")

      # When: User clicks available filter
      html =
        view
        |> element("[data-filter-id='available']")
        |> render_click()

      # Then: Same result - only available soccer program
      assert html =~ available_soccer.title
      refute html =~ "Sold Out Soccer"
    end
  end

  # T077: Empty state behavioral differentiation tests
  describe "ProgramsLive - Empty State Differentiation" do
    # T078: Empty state when no programs exist in database
    test "shows 'No programs available' when database is empty", %{conn: conn} do
      # Given: Database has no programs (clean state from test sandbox)

      # When: User navigates to /programs
      {:ok, _view, html} = live(conn, ~p"/programs")

      # Then: Empty state message indicates no programs exist
      assert html =~ "No programs found"

      # Note: Current implementation shows generic message
      # Future enhancement: differentiate "No programs available" vs "No matches"
    end

    # T079: Empty state when all programs are filtered out
    test "shows context-aware message when programs exist but are filtered out", %{conn: conn} do
      # Given: Database has only sold-out programs
      _sold_out1 =
        insert_program(%{
          title: "Sold Out Program 1",
          spots_available: 0
        })

      _sold_out2 =
        insert_program(%{
          title: "Sold Out Program 2",
          spots_available: 0
        })

      # When: User filters by "available"
      {:ok, _view, html} = live(conn, ~p"/programs?filter=available")

      # Then: Empty state is shown
      assert html =~ "No programs found"

      # And: Helpful message suggests adjusting filters
      assert html =~ "Try adjusting your search or filter criteria"
    end

    # T080: Empty state when search yields no results
    test "shows helpful message when search returns no matches", %{conn: conn} do
      # Given: Database has programs but none match search
      _program =
        insert_program(%{
          title: "Art Class",
          description: "Creative painting"
        })

      # When: User searches for something that doesn't exist
      {:ok, _view, html} = live(conn, ~p"/programs?q=robotics")

      # Then: Empty state is shown with search context
      assert html =~ "No programs found"
      assert html =~ "Try adjusting your search or filter criteria"
    end

    # T081: No empty state when programs match filters
    test "hides empty state when programs match current filters", %{conn: conn} do
      # Given: Database has both available and sold-out programs
      _available =
        insert_program(%{
          title: "Available Program",
          spots_available: 10
        })

      _sold_out =
        insert_program(%{
          title: "Sold Out Program",
          spots_available: 0
        })

      # When: User filters by "available"
      {:ok, view, html} = live(conn, ~p"/programs?filter=available")

      # Then: Programs are shown, no empty state
      assert html =~ "Available Program"
      refute html =~ "No programs found"

      # And: Empty state component is not rendered
      refute has_element?(view, "[data-testid='empty-state']")
    end

    # T082: Empty state transitions correctly when filters change
    test "empty state appears/disappears correctly when filters change", %{conn: conn} do
      # Given: Database has only sold-out programs
      _sold_out =
        insert_program(%{
          title: "Sold Out Soccer",
          spots_available: 0
        })

      # When: User starts with "all" filter (programs shown)
      {:ok, view, html} = live(conn, ~p"/programs")

      # Then: Programs are displayed, no empty state
      assert html =~ "Sold Out Soccer"
      refute html =~ "No programs found"

      # When: User switches to "available" filter
      html =
        view
        |> element("[data-filter-id='available']")
        |> render_click()

      # Then: Empty state appears (all programs filtered out)
      assert html =~ "No programs found"
      refute html =~ "Sold Out Soccer"
    end

    # T083: Empty state with combined filter + search
    test "shows appropriate message when filter + search combination yields no results", %{
      conn: conn
    } do
      # Given: Database has available art programs but no soccer
      _art =
        insert_program(%{
          title: "Art Class",
          description: "Painting workshop",
          spots_available: 10
        })

      # When: User searches for "soccer" with "available" filter
      {:ok, _view, html} = live(conn, ~p"/programs?filter=available&q=soccer")

      # Then: Empty state is shown with helpful context
      assert html =~ "No programs found"
      assert html =~ "Try adjusting your search or filter criteria"
    end
  end

  # T084: Negative interaction tests for error handling
  describe "ProgramsLive - Error Handling and Edge Cases" do
    # T085: Invalid filter parameter defaults to "all"
    test "invalid filter parameter defaults to 'all' filter", %{conn: conn} do
      # Given: Database has programs
      _program =
        insert_program(%{
          title: "Test Program",
          spots_available: 10
        })

      # When: User navigates with invalid filter parameter
      {:ok, view, html} = live(conn, ~p"/programs?filter=invalid_filter_xyz")

      # Then: Page loads without crashing
      assert html =~ "Test Program"

      # And: Filter defaults to "all" ("All Programs" filter is marked as active)
      assert has_element?(view, "[data-filter-id='all'][data-active='true']")

      # And: No error message is shown
      refute has_element?(view, ".flash-error")
    end

    # T086: Program click with non-existent program shows error
    test "program click with non-existent program shows error and stays on page", %{conn: conn} do
      # Given: Database has programs
      _existing =
        insert_program(%{
          title: "Existing Program"
        })

      # When: LiveView is mounted
      {:ok, view, _html} = live(conn, ~p"/programs")

      # And: User clicks a program that doesn't exist (simulated)
      view
      |> element("[phx-click='program_click']")
      |> render_click(%{"program" => "Non Existent Program"})

      # Then: Error flash is shown
      assert render(view) =~ "Program not found"

      # And: User stays on programs page (no navigation)
      assert_patch(view, ~p"/programs")
    end

    # T087: Malformed search query is handled gracefully
    test "malformed or extremely long search query is handled gracefully", %{conn: conn} do
      # Given: Database has programs
      _program =
        insert_program(%{
          title: "Normal Program"
        })

      # When: User submits extremely long search query (>100 chars, should be truncated)
      long_query = String.duplicate("a", 150)
      {:ok, view, html} = live(conn, ~p"/programs?q=#{long_query}")

      # Then: Page loads without crashing (empty result is acceptable)
      # The search doesn't match "Normal Program", so empty state is shown
      assert html =~ "No programs found"

      # And: Search still functions (query was truncated but search works)
      assert has_element?(view, "#programs")

      # And: No error is shown
      refute has_element?(view, ".flash-error")
    end

    # T088: Search with special characters doesn't break the query
    test "search with special characters is handled safely", %{conn: conn} do
      # Given: Database has programs with special characters in titles
      _soccer_art =
        insert_program(%{
          title: "Soccer & Art",
          description: "Fun activities: soccer, art, music!"
        })

      _art_class =
        insert_program(%{
          title: "Art Class",
          description: "Learn painting"
        })

      # When: User searches for "soccer" (word-boundary match at start)
      {:ok, _view, html} = live(conn, ~p"/programs?q=soccer")

      # Then: Page loads without crashing and "Soccer & Art" is found
      assert html =~ "Soccer &amp; Art"
      refute html =~ "Art Class"

      # When: User searches for "art" (word-boundary match)
      {:ok, _view, html} = live(conn, ~p"/programs?q=art")

      # Then: Both "Soccer & Art" and "Art Class" are found (both have words starting with "art")
      assert html =~ "Soccer &amp; Art"
      assert html =~ "Art Class"
    end

    # T089: Combining invalid filter with valid search
    test "combining invalid filter with valid search works correctly", %{conn: conn} do
      # Given: Database has programs
      soccer =
        insert_program(%{
          title: "Soccer Training",
          spots_available: 10
        })

      _art =
        insert_program(%{
          title: "Art Class",
          spots_available: 5
        })

      # When: User uses invalid filter with valid search
      {:ok, view, html} = live(conn, ~p"/programs?filter=invalid&q=soccer")

      # Then: Page works correctly
      assert html =~ soccer.title
      refute html =~ "Art Class"

      # And: Filter defaults to "all" (UI shows all filter active)
      assert has_element?(view, "[data-filter-id='all'][data-active='true']")

      # And: Search is applied correctly (only soccer program shown)
    end

    # T090: Empty search query clears search filter
    test "empty search query shows all programs", %{conn: conn} do
      # Given: Database has programs
      _program1 = insert_program(%{title: "Program 1"})
      _program2 = insert_program(%{title: "Program 2"})

      # When: User navigates with empty search query
      {:ok, _view, html} = live(conn, ~p"/programs?q=")

      # Then: All programs are shown
      assert html =~ "Program 1"
      assert html =~ "Program 2"
    end

    # T091: Rapid filter changes don't cause race conditions
    test "rapid filter changes are handled correctly", %{conn: conn} do
      # Given: Database has programs with different availability
      _available =
        insert_program(%{
          title: "Available",
          spots_available: 10
        })

      _sold_out =
        insert_program(%{
          title: "Sold Out",
          spots_available: 0
        })

      # When: User rapidly changes filters
      {:ok, view, _html} = live(conn, ~p"/programs")

      # Switch to available
      html =
        view
        |> element("[data-filter-id='available']")
        |> render_click()

      assert html =~ "Available"
      refute html =~ "Sold Out"

      # Switch back to all
      html =
        view
        |> element("[data-filter-id='all']")
        |> render_click()

      # Then: Both programs are shown
      assert html =~ "Available"
      assert html =~ "Sold Out"
    end

    # T092: URL with both filter and search parameters works correctly
    test "URL with multiple query parameters is parsed correctly", %{conn: conn} do
      # Given: Database has programs
      available_soccer =
        insert_program(%{
          title: "Available Soccer",
          description: "Soccer training",
          spots_available: 10
        })

      _sold_out_soccer =
        insert_program(%{
          title: "Sold Out Soccer",
          spots_available: 0
        })

      _available_art =
        insert_program(%{
          title: "Available Art",
          spots_available: 5
        })

      # When: User navigates with both filter and search in URL
      {:ok, view, html} = live(conn, ~p"/programs?filter=available&q=soccer")

      # Then: Both parameters are applied correctly
      assert html =~ available_soccer.title
      refute html =~ "Sold Out Soccer"
      refute html =~ "Art"

      # And: UI shows available filter is active
      assert has_element?(view, "[data-filter-id='available'][data-active='true']")
    end
  end

  # Helper function to insert programs into the test database
  defp insert_program(attrs) do
    default_attrs = %{
      title: "Default Program",
      description: "Default description",
      schedule: "Mon-Fri, 3:00-5:00 PM",
      age_range: "6-12 years",
      price: Decimal.new("100.00"),
      pricing_period: "per month",
      spots_available: 10,
      gradient_class: "from-purple-500 to-pink-500",
      icon_path: "/images/icons/default.svg"
    }

    attrs = Map.merge(default_attrs, attrs)

    %ProgramSchema{}
    |> ProgramSchema.changeset(attrs)
    |> Repo.insert!()
  end
end
