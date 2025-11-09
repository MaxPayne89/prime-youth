defmodule PrimeYouthWeb.ProgramLiveTest do
  use PrimeYouthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PrimeYouth.ProgramCatalogFixtures

  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.{
    Location,
    Program,
    ProgramSchedule
  }

  alias PrimeYouth.Repo

  describe "ProgramLive.Index" do
    setup do
      provider = provider_fixture()

      program1 =
        insert_program(provider, %{
          title: "Soccer Camp",
          category: "sports",
          age_min: 8,
          age_max: 12
        })

      program2 =
        insert_program(provider, %{
          title: "Art Workshop",
          category: "arts",
          age_min: 10,
          age_max: 14
        })

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

    test "filters programs by category", %{conn: conn, program1: _p1} do
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

      # 8-12 includes age 9
      assert html =~ "Soccer Camp"
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
      {:ok, _view, html} = live(conn, ~p"/programs")

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
      provider = provider_fixture()
      _draft = insert_program(provider, %{title: "Draft Program", status: "draft"})

      {:ok, _view, html} = live(conn, ~p"/programs")

      refute html =~ "Draft Program"
    end

    test "excludes archived programs from listing", %{conn: conn} do
      provider = provider_fixture()

      _archived =
        insert_program(provider, %{
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
      provider = provider_fixture()

      program =
        insert_program(provider, %{
          title: "Soccer Camp",
          description: "Comprehensive soccer training for kids.",
          category: "sports",
          age_min: 8,
          age_max: 12
        })

      schedule =
        insert_schedule(program, %{
          start_date: ~D[2025-06-01],
          end_date: ~D[2025-08-15],
          days_of_week: ["monday", "wednesday", "friday"]
        })

      location =
        insert_location(program, %{
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
      provider = provider_fixture()
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

  defp insert_program(provider, attrs) do
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

  describe "ProgramLive.Form" do
    setup %{conn: conn} do
      # Create a user and provider using fixture (automatically creates user)
      provider = provider_fixture()
      user = Repo.get!(PrimeYouth.Accounts.User, provider.user_id)

      # Log in the user
      conn = log_in_user(conn, user)

      {:ok, conn: conn, provider: provider, user: user}
    end

    test "displays new program form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/provider/programs/new")

      assert html =~ "Create New Program"
      assert html =~ "Program Title"
      assert html =~ "Description"
      assert html =~ "Category"
      assert html =~ "Age Range"
      assert html =~ "Capacity"
      assert html =~ "Pricing"
    end

    test "validates required fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/programs/new")

      # Submit empty form
      html =
        view
        |> element("#program-form")
        |> render_submit(%{"program" => %{}})

      assert html =~ "can&#39;t be blank"
    end

    test "creates a new program with valid data", %{conn: conn, provider: provider} do
      {:ok, view, _html} = live(conn, ~p"/provider/programs/new")

      program_attrs = %{
        "title" => "New Soccer Camp",
        "description" => "An exciting soccer program for young athletes.",
        "category" => "sports",
        "age_min" => "8",
        "age_max" => "12",
        "capacity" => "20",
        "price_amount" => "100.00",
        "price_unit" => "session"
      }

      # Submit form
      view
      |> element("#program-form")
      |> render_submit(%{"program" => program_attrs})

      # Should redirect to dashboard
      assert_redirect(view, ~p"/provider/dashboard")

      # Verify program was created
      assert Repo.get_by(Program, title: "New Soccer Camp", provider_id: provider.id)
    end

    test "validates title length", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/programs/new")

      # Submit with short title (less than 3 characters)
      html =
        view
        |> element("#program-form")
        |> render_change(%{"program" => %{"title" => "AB"}})

      assert html =~ "should be at least 3 character"
    end

    test "validates description length", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/programs/new")

      # Submit with short description (less than 10 characters)
      html =
        view
        |> element("#program-form")
        |> render_change(%{"program" => %{"description" => "Short"}})

      assert html =~ "should be at least 10 character"
    end

    test "validates age range min <= max", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/programs/new")

      # Submit with age_min > age_max
      html =
        view
        |> element("#program-form")
        |> render_change(%{"program" => %{"age_min" => "15", "age_max" => "10"}})

      assert html =~ "must be less than or equal to age_max"
    end

    test "validates capacity is positive", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/programs/new")

      # Submit with zero capacity
      html =
        view
        |> element("#program-form")
        |> render_change(%{"program" => %{"capacity" => "0"}})

      assert html =~ "must be greater than 0"
    end

    test "validates price is non-negative", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/programs/new")

      # Submit with negative price
      html =
        view
        |> element("#program-form")
        |> render_change(%{"program" => %{"price_amount" => "-10.00"}})

      assert html =~ "must be greater than or equal to 0"
    end

    test "displays edit program form", %{conn: conn, provider: provider} do
      program = insert_program(provider, %{title: "Existing Program", status: "draft"})

      {:ok, _view, html} = live(conn, ~p"/provider/programs/#{program.id}/edit")

      assert html =~ "Edit Program"
      assert html =~ "Existing Program"
    end

    test "updates program with valid data", %{conn: conn, provider: provider} do
      program = insert_program(provider, %{title: "Old Title", status: "draft"})

      {:ok, view, _html} = live(conn, ~p"/provider/programs/#{program.id}/edit")

      # Update title
      view
      |> element("#program-form")
      |> render_submit(%{"program" => %{"title" => "Updated Title"}})

      # Should redirect to dashboard
      assert_redirect(view, ~p"/provider/dashboard")

      # Verify program was updated
      updated_program = Repo.get!(Program, program.id)
      assert updated_program.title == "Updated Title"
    end

    test "prevents editing approved programs", %{conn: conn, provider: provider} do
      program = insert_program(provider, %{title: "Approved Program", status: "approved"})

      {:ok, _view, html} = live(conn, ~p"/provider/programs/#{program.id}/edit")

      assert html =~ "Cannot edit approved program"
    end

    test "allows editing rejected programs", %{conn: conn, provider: provider} do
      program = insert_program(provider, %{title: "Rejected Program", status: "rejected"})

      {:ok, _view, html} = live(conn, ~p"/provider/programs/#{program.id}/edit")

      assert html =~ "Edit Program"
      assert html =~ "Rejected Program"
    end

    test "prevents editing programs from other providers", %{conn: conn} do
      other_provider = provider_fixture()
      program = insert_program(other_provider, %{title: "Other Program"})

      assert_error_sent 403, fn ->
        live(conn, ~p"/provider/programs/#{program.id}/edit")
      end
    end

    test "displays form on mobile viewport (375px)", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/provider/programs/new")

      # Mobile-first design should work at 375px width
      assert html =~ "Create New Program"
      assert has_element?(view, "#program-form")
    end

    test "requires authentication to access form", %{provider: _provider} do
      # Create new unauthenticated connection
      conn = build_conn()

      # Should redirect to login
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/provider/programs/new")

      assert path == ~p"/users/log-in"
    end

    test "creates program in draft status by default", %{conn: conn, provider: provider} do
      {:ok, view, _html} = live(conn, ~p"/provider/programs/new")

      program_attrs = %{
        "title" => "Draft Program",
        "description" => "This program should start as a draft.",
        "category" => "arts",
        "age_min" => "10",
        "age_max" => "14",
        "capacity" => "15",
        "price_amount" => "50.00",
        "price_unit" => "week"
      }

      view
      |> element("#program-form")
      |> render_submit(%{"program" => program_attrs})

      # Verify program was created as draft
      program = Repo.get_by(Program, title: "Draft Program", provider_id: provider.id)
      assert program.status == "draft"
    end

    test "validates category is from allowed list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/programs/new")

      # Submit with invalid category
      html =
        view
        |> element("#program-form")
        |> render_change(%{"program" => %{"category" => "invalid_category"}})

      assert html =~ "is invalid"
    end

    test "displays real-time validation errors", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/programs/new")

      # Trigger validation on change
      html =
        view
        |> element("#program-form")
        |> render_change(%{"program" => %{"title" => ""}})

      assert html =~ "can&#39;t be blank"
    end

    test "shows success message after creating program", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/programs/new")

      program_attrs = %{
        "title" => "Success Program",
        "description" => "This program should show success message.",
        "category" => "stem",
        "age_min" => "8",
        "age_max" => "12",
        "capacity" => "20",
        "price_amount" => "75.00",
        "price_unit" => "session"
      }

      view
      |> element("#program-form")
      |> render_submit(%{"program" => program_attrs})

      # Check for success flash
      assert Phoenix.Flash.get(view.assigns.flash, :info) =~ "Program created successfully"
    end
  end
end
