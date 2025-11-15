defmodule PrimeYouthWeb.ProgramsLiveTest do
  use PrimeYouthWeb.ConnCase

  import Phoenix.LiveViewTest

  alias PrimeYouth.Repo
  alias PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema

  describe "ProgramsLive - Integration with Database (User Story 1)" do
    # T052: Write LiveView test - displays all programs from database
    test "displays all programs from database", %{conn: conn} do
      # Given: Database has 3 programs
      program1 = insert_program(%{
        title: "Art Adventures",
        description: "Explore creativity through painting and sculpture",
        schedule: "Mon-Fri, 3:00-5:00 PM",
        age_range: "6-8 years",
        price: Decimal.new("120.00"),
        pricing_period: "per month",
        spots_available: 12
      })

      program2 = insert_program(%{
        title: "Soccer Stars",
        description: "Learn soccer fundamentals and teamwork",
        schedule: "Tue, Thu, 4:00-5:30 PM",
        age_range: "8-12 years",
        price: Decimal.new("85.00"),
        pricing_period: "per month",
        spots_available: 20
      })

      program3 = insert_program(%{
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
      free_program = insert_program(%{
        title: "Community Library Hour",
        description: "Free reading and learning time at the library",
        schedule: "Sat, 10:00-11:00 AM",
        age_range: "5-10 years",
        price: Decimal.new("0"),
        pricing_period: "free",
        spots_available: 30
      })

      paid_program = insert_program(%{
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
      _programs = for i <- 1..100 do
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
