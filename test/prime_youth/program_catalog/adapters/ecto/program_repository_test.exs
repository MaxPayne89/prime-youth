defmodule PrimeYouth.ProgramCatalog.Adapters.Ecto.ProgramRepositoryTest do
  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.ProgramRepository
  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.{Program, Provider, ProgramSchedule, Location}

  describe "list/1" do
    setup do
      provider = insert_provider()
      program1 = insert_program(provider, %{title: "Soccer Camp", category: "sports", age_min: 8, age_max: 12})
      program2 = insert_program(provider, %{title: "Art Workshop", category: "arts", age_min: 10, age_max: 14})
      program3 = insert_program(provider, %{title: "Math Tutoring", category: "academic", age_min: 6, age_max: 10})

      {:ok, provider: provider, program1: program1, program2: program2, program3: program3}
    end

    test "returns all programs with empty filters", %{program1: p1, program2: p2, program3: p3} do
      programs = ProgramRepository.list(%{})

      assert length(programs) == 3
      program_ids = Enum.map(programs, & &1.id)
      assert p1.id in program_ids
      assert p2.id in program_ids
      assert p3.id in program_ids
    end

    test "filters by category", %{program1: p1} do
      programs = ProgramRepository.list(%{category: "sports"})

      assert length(programs) == 1
      assert hd(programs).id == p1.id
      assert hd(programs).category == "sports"
    end

    test "filters by age range (overlaps with program age range)", %{program1: p1, program3: p3} do
      # Query for age 9 should match programs covering that age
      programs = ProgramRepository.list(%{age_min: 9, age_max: 9})

      assert length(programs) == 2
      program_ids = Enum.map(programs, & &1.id)
      assert p1.id in program_ids  # 8-12 covers age 9
      assert p3.id in program_ids  # 6-10 covers age 9
    end

    test "filters by location city" do
      provider = insert_provider()
      program = insert_program(provider, %{title: "SF Program"})
      insert_location(program, %{city: "San Francisco"})

      programs = ProgramRepository.list(%{city: "San Francisco"})

      assert length(programs) == 1
      assert hd(programs).id == program.id
    end

    test "filters by price range" do
      provider = insert_provider()
      cheap_program = insert_program(provider, %{title: "Cheap", price_amount: Decimal.new("50.00")})
      expensive_program = insert_program(provider, %{title: "Expensive", price_amount: Decimal.new("500.00")})

      programs = ProgramRepository.list(%{price_min: 40, price_max: 100})

      assert length(programs) == 1
      assert hd(programs).id == cheap_program.id
    end

    test "filters by is_prime_youth" do
      provider = insert_provider()
      prime_program = insert_program(provider, %{title: "Prime Youth Program", is_prime_youth: true})
      _external_program = insert_program(provider, %{title: "External Program", is_prime_youth: false})

      programs = ProgramRepository.list(%{is_prime_youth: true})

      assert length(programs) == 1
      assert hd(programs).id == prime_program.id
    end

    test "filters by status" do
      provider = insert_provider()
      approved = insert_program(provider, %{title: "Approved", status: "approved"})
      _draft = insert_program(provider, %{title: "Draft", status: "draft"})

      programs = ProgramRepository.list(%{status: "approved"})

      assert length(programs) == 1
      assert hd(programs).id == approved.id
    end

    test "combines multiple filters", %{program1: p1} do
      programs = ProgramRepository.list(%{
        category: "sports",
        age_min: 8,
        age_max: 12
      })

      assert length(programs) == 1
      assert hd(programs).id == p1.id
    end

    test "returns empty list when no matches" do
      programs = ProgramRepository.list(%{category: "nonexistent"})
      assert programs == []
    end
  end

  describe "get/1" do
    test "returns program with preloaded associations" do
      provider = insert_provider()
      program = insert_program(provider, %{title: "Test Program"})
      schedule = insert_schedule(program)
      location = insert_location(program)

      assert {:ok, fetched} = ProgramRepository.get(program.id)
      assert fetched.id == program.id
      assert fetched.provider.id == provider.id
      assert length(fetched.schedules) == 1
      assert hd(fetched.schedules).id == schedule.id
      assert length(fetched.locations) == 1
      assert hd(fetched.locations).id == location.id
    end

    test "returns error when program not found" do
      assert {:error, :not_found} = ProgramRepository.get(Ecto.UUID.generate())
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
