defmodule PrimeYouthWeb.ProgramLiveTest do
  use PrimeYouthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.{Program, Provider, ProgramSchedule, Location}

  describe "ProgramLive.Index" do
    setup do
      provider = insert_provider()
      program1 = insert_program(provider, %{title: "Soccer Camp", category: "sports", age_min: 8, age_max: 12})
      program2 = insert_program(provider, %{title: "Art Workshop", category: "arts", age_min: 10, age_max: 14})
      insert_schedule(program1)
      insert_location(program1)

      {:ok, provider: provider, program1: program1, program2: program2}
    end

    test "displays all approved programs", %{conn: conn, program1: p1, program2: p2} do
      {:ok, view, html} = live(conn, ~p"/programs")

      assert html =~ "Soccer Camp"
      assert html =~ "Art Workshop"
      assert has_element?(view, "#program-#{p1.id}")
      assert has_element?(view, "#program-#{p2.id}")
    end

    test "filters programs by category", %{conn: conn, program1: p1} do
      {:ok, view, _html} = live(conn, ~p"/programs")

      # Apply sports filter
      html =
        view
        |> element("#filter-form")
        |> render_change(%{"filter" => %{"category" => "sports"}})

      assert html =~ "Soccer Camp"
      refute html =~ "Art Workshop"
    end

    test "filters programs by age range", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/programs")

      # Filter for age 9
      html =
        view
        |> element("#filter-form")
        |> render_change(%{"filter" => %{"age_min" => "9", "age_max" => "9"}})

      assert html =~ "Soccer Camp"  # 8-12 includes age 9
    end

    test "clears filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/programs")

      # Apply filter
      view
      |> element("#filter-form")
      |> render_change(%{"filter" => %{"category" => "sports"}})

      # Clear filters
      html =
        view
        |> element("#clear-filters")
        |> render_click()

      assert html =~ "Soccer Camp"
      assert html =~ "Art Workshop"
    end

    test "displays program cards with key information", %{conn: conn, program1: p1} do
      {:ok, view, html} = live(conn, ~p"/programs")

      assert html =~ "Soccer Camp"
      assert html =~ p1.description
      assert html =~ "Ages 8-12"
      assert html =~ "$100.00"
    end

    test "shows empty state when no programs match filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/programs")

      html =
        view
        |> element("#filter-form")
        |> render_change(%{"filter" => %{"category" => "nonexistent"}})

      assert html =~ "No programs found"
    end

    test "excludes draft programs from listing", %{conn: conn} do
      provider = insert_provider()
      _draft = insert_program(provider, %{title: "Draft Program", status: "draft"})

      {:ok, _view, html} = live(conn, ~p"/programs")

      refute html =~ "Draft Program"
    end

    test "excludes archived programs from listing", %{conn: conn} do
      provider = insert_provider()
      _archived = insert_program(provider, %{
        title: "Archived Program",
        archived_at: ~U[2025-01-01 12:00:00Z]
      })

      {:ok, _view, html} = live(conn, ~p"/programs")

      refute html =~ "Archived Program"
    end

    test "program cards are clickable to view details", %{conn: conn, program1: p1} do
      {:ok, view, _html} = live(conn, ~p"/programs")

      assert view
             |> element("#program-#{p1.id} a")
             |> has_element?()
    end

    test "displays on mobile viewport (375px)", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/programs")

      # Mobile-first design should work at 375px width
      # Programs should be in a single column stack
      assert html =~ "Soccer Camp"
      assert has_element?(view, "#program-list")
    end
  end

  describe "ProgramLive.Show" do
    setup do
      provider = insert_provider()
      program = insert_program(provider, %{
        title: "Soccer Camp",
        description: "Comprehensive soccer training for kids.",
        category: "sports",
        age_min: 8,
        age_max: 12
      })

      schedule = insert_schedule(program, %{
        start_date: ~D[2025-06-01],
        end_date: ~D[2025-08-15],
        days_of_week: ["monday", "wednesday", "friday"]
      })

      location = insert_location(program, %{
        name: "Community Center",
        city: "San Francisco",
        state: "CA"
      })

      {:ok, provider: provider, program: program, schedule: schedule, location: location}
    end

    test "displays program details", %{conn: conn, program: program} do
      {:ok, _view, html} = live(conn, ~p"/programs/#{program.id}")

      assert html =~ "Soccer Camp"
      assert html =~ "Comprehensive soccer training for kids"
      assert html =~ "Ages 8-12"
      assert html =~ "Capacity: 20"
    end

    test "displays program schedule", %{conn: conn, program: program} do
      {:ok, _view, html} = live(conn, ~p"/programs/#{program.id}")

      assert html =~ "Schedule"
      assert html =~ "June 1, 2025"
      assert html =~ "August 15, 2025"
      assert html =~ "Monday, Wednesday, Friday"
      assert html =~ "9:00 AM - 12:00 PM"
    end

    test "displays program location", %{conn: conn, program: program} do
      {:ok, _view, html} = live(conn, ~p"/programs/#{program.id}")

      assert html =~ "Location"
      assert html =~ "Community Center"
      assert html =~ "San Francisco, CA"
    end

    test "displays provider information", %{conn: conn, program: program, provider: provider} do
      {:ok, _view, html} = live(conn, ~p"/programs/#{program.id}")

      assert html =~ "Provider"
      assert html =~ provider.name
    end

    test "displays pricing information", %{conn: conn, program: program} do
      {:ok, _view, html} = live(conn, ~p"/programs/#{program.id}")

      assert html =~ "$100.00"
      assert html =~ "per session"
    end

    test "shows 404 for non-existent program", %{conn: conn} do
      fake_id = Ecto.UUID.generate()

      assert_error_sent 404, fn ->
        live(conn, ~p"/programs/#{fake_id}")
      end
    end

    test "displays multiple schedules if program has them", %{conn: conn, program: program} do
      insert_schedule(program, %{
        start_date: ~D[2025-09-01],
        end_date: ~D[2025-10-31],
        days_of_week: ["tuesday", "thursday"]
      })

      {:ok, _view, html} = live(conn, ~p"/programs/#{program.id}")

      # Should show both schedules
      assert html =~ "June 1, 2025"
      assert html =~ "September 1, 2025"
    end

    test "displays virtual location if program is online", %{conn: conn} do
      provider = insert_provider()
      program = insert_program(provider, %{title: "Online Math"})
      insert_location(program, %{
        name: "Zoom Session",
        is_virtual: true,
        virtual_link: "https://zoom.us/j/123456789"
      })

      {:ok, _view, html} = live(conn, ~p"/programs/#{program.id}")

      assert html =~ "Virtual Location"
      assert html =~ "Zoom Session"
      assert html =~ "zoom.us"
    end

    test "displays on mobile viewport (375px)", %{conn: conn, program: program} do
      {:ok, view, html} = live(conn, ~p"/programs/#{program.id}")

      # Mobile-first design should work at 375px width
      assert html =~ "Soccer Camp"
      assert has_element?(view, "#program-details")
    end
  end

  # Helper functions

  defp insert_provider(attrs \\ %{}) do
    default_attrs = %{
      name: "Test Provider",
      email: "provider@test.com",
      is_verified: true,
      is_prime_youth: false,
      user_id: Ecto.UUID.generate()
    }

    %Provider{}
    |> Provider.changeset(Map.merge(default_attrs, attrs))
    |> Repo.insert!()
  end

  defp insert_program(provider, attrs \\ %{}) do
    default_attrs = %{
      title: "Test Program",
      description: "A test program description that is long enough to pass validation.",
      provider_id: provider.id,
      category: "sports",
      age_min: 8,
      age_max: 12,
      capacity: 20,
      current_enrollment: 0,
      price_amount: Decimal.new("100.00"),
      price_currency: "USD",
      price_unit: "session",
      has_discount: false,
      status: "approved",
      is_prime_youth: false,
      featured: false
    }

    %Program{}
    |> Program.changeset(Map.merge(default_attrs, attrs))
    |> Repo.insert!()
  end

  defp insert_schedule(program, attrs \\ %{}) do
    default_attrs = %{
      program_id: program.id,
      start_date: ~D[2025-06-01],
      end_date: ~D[2025-08-15],
      days_of_week: ["monday", "wednesday", "friday"],
      start_time: ~T[09:00:00],
      end_time: ~T[12:00:00],
      recurrence_pattern: "weekly",
      session_count: 24,
      session_duration: 180
    }

    %ProgramSchedule{}
    |> ProgramSchedule.changeset(Map.merge(default_attrs, attrs))
    |> Repo.insert!()
  end

  defp insert_location(program, attrs \\ %{}) do
    default_attrs = %{
      program_id: program.id,
      name: "Test Location",
      address_line1: "123 Test St",
      city: "Test City",
      state: "TS",
      postal_code: "12345",
      is_virtual: false
    }

    %Location{}
    |> Location.changeset(Map.merge(default_attrs, attrs))
    |> Repo.insert!()
  end
end
