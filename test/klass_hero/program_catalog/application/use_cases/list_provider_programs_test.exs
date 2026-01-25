defmodule KlassHero.ProgramCatalog.Application.UseCases.ListProviderProgramsTest do
  @moduledoc """
  Tests for the ListProviderPrograms use case.

  This test suite verifies the use case orchestration logic without testing
  repository implementation details. We use a mock repository to focus on
  use case behavior.

  Test Coverage:
  - Returns programs for valid provider_id
  - Returns empty list when provider has no programs
  - Returns empty list for non-existent provider_id
  - Programs ordered by title
  """

  use ExUnit.Case, async: true

  alias KlassHero.ProgramCatalog.Application.UseCases.ListProviderPrograms
  alias KlassHero.ProgramCatalog.Domain.Models.Program

  # Mock repository for testing
  defmodule MockRepository do
    @moduledoc false
    @behaviour KlassHero.ProgramCatalog.Domain.Ports.ForListingPrograms

    def list_all_programs do
      {:error, :not_implemented}
    end

    def get_by_id(_id) do
      {:error, :not_implemented}
    end

    def list_programs_paginated(_limit, _cursor) do
      {:error, :not_implemented}
    end

    def list_programs_paginated(_limit, _cursor, _category) do
      {:error, :not_implemented}
    end

    def list_programs_for_provider(provider_id) do
      case Process.get(:mock_provider_programs) do
        nil -> []
        programs_by_provider -> Map.get(programs_by_provider, provider_id, [])
      end
    end
  end

  setup do
    # Store original config
    original_config = Application.get_env(:klass_hero, :program_catalog)

    # Configure use case to use mock repository
    Application.put_env(:klass_hero, :program_catalog, repository: __MODULE__.MockRepository)

    on_exit(fn ->
      # Restore original config
      if original_config do
        Application.put_env(:klass_hero, :program_catalog, original_config)
      else
        Application.delete_env(:klass_hero, :program_catalog)
      end

      # Clean up process dictionary
      Process.delete(:mock_provider_programs)
    end)

    :ok
  end

  describe "execute/1" do
    test "returns programs for valid provider_id" do
      provider_id = "550e8400-e29b-41d4-a716-446655440001"

      program1 = %Program{
        id: "660e8400-e29b-41d4-a716-446655440001",
        title: "Soccer Stars",
        description: "Learn soccer fundamentals",
        category: "sports",
        schedule: "Mon-Wed 3-5pm",
        age_range: "6-10 years",
        price: Decimal.new("150.00"),
        pricing_period: "per month",
        spots_available: 12,
        icon_path: "/images/icons/soccer.svg",
        inserted_at: ~U[2025-01-01 12:00:00Z],
        updated_at: ~U[2025-01-01 12:00:00Z]
      }

      program2 = %Program{
        id: "660e8400-e29b-41d4-a716-446655440002",
        title: "Art Adventure",
        description: "Explore creativity",
        category: "arts",
        schedule: "Tue-Thu 4-6pm",
        age_range: "7-12 years",
        price: Decimal.new("120.00"),
        pricing_period: "per month",
        spots_available: 8,
        icon_path: "/images/icons/art.svg",
        inserted_at: ~U[2025-01-02 10:00:00Z],
        updated_at: ~U[2025-01-02 10:00:00Z]
      }

      Process.put(:mock_provider_programs, %{provider_id => [program1, program2]})

      programs = ListProviderPrograms.execute(provider_id)

      assert length(programs) == 2
      assert Enum.at(programs, 0) == program1
      assert Enum.at(programs, 1) == program2
    end

    test "returns empty list when provider has no programs" do
      provider_id = "550e8400-e29b-41d4-a716-446655440002"

      Process.put(:mock_provider_programs, %{provider_id => []})

      programs = ListProviderPrograms.execute(provider_id)

      assert programs == []
    end

    test "returns empty list for non-existent provider_id" do
      provider_id = "non-existent-provider-id"

      Process.put(:mock_provider_programs, %{})

      programs = ListProviderPrograms.execute(provider_id)

      assert programs == []
    end

    test "programs are ordered by title" do
      provider_id = "550e8400-e29b-41d4-a716-446655440003"

      # Create programs with titles in non-alphabetical order
      program_z = %Program{
        id: "660e8400-e29b-41d4-a716-446655440003",
        title: "Zebra Club",
        description: "Wildlife education",
        category: "education",
        schedule: "Fri 2-4pm",
        age_range: "5-8 years",
        price: Decimal.new("100.00"),
        pricing_period: "per session",
        spots_available: 15,
        icon_path: nil,
        inserted_at: ~U[2025-01-03 09:00:00Z],
        updated_at: ~U[2025-01-03 09:00:00Z]
      }

      program_a = %Program{
        id: "660e8400-e29b-41d4-a716-446655440004",
        title: "Art Class",
        description: "Creative arts",
        category: "arts",
        schedule: "Mon 3-5pm",
        age_range: "6-9 years",
        price: Decimal.new("80.00"),
        pricing_period: "per session",
        spots_available: 10,
        icon_path: "/images/icons/paint.svg",
        inserted_at: ~U[2025-01-04 11:00:00Z],
        updated_at: ~U[2025-01-04 11:00:00Z]
      }

      program_m = %Program{
        id: "660e8400-e29b-41d4-a716-446655440005",
        title: "Music Camp",
        description: "Learn music",
        category: "music",
        schedule: "Wed 4-6pm",
        age_range: "8-14 years",
        price: Decimal.new("200.00"),
        pricing_period: "per month",
        spots_available: 6,
        icon_path: "/images/icons/music.svg",
        inserted_at: ~U[2025-01-05 08:00:00Z],
        updated_at: ~U[2025-01-05 08:00:00Z]
      }

      # Mock returns pre-sorted by title (as repository should)
      Process.put(:mock_provider_programs, %{provider_id => [program_a, program_m, program_z]})

      programs = ListProviderPrograms.execute(provider_id)

      assert length(programs) == 3
      titles = Enum.map(programs, & &1.title)
      assert titles == ["Art Class", "Music Camp", "Zebra Club"]
    end

    test "handles provider with single program" do
      provider_id = "550e8400-e29b-41d4-a716-446655440004"

      program = %Program{
        id: "660e8400-e29b-41d4-a716-446655440006",
        title: "Single Program",
        description: "Only one program",
        category: "education",
        schedule: "Sat 10am-12pm",
        age_range: "6-12 years",
        price: Decimal.new("50.00"),
        pricing_period: "per session",
        spots_available: 20,
        icon_path: nil,
        inserted_at: ~U[2025-01-06 10:00:00Z],
        updated_at: ~U[2025-01-06 10:00:00Z]
      }

      Process.put(:mock_provider_programs, %{provider_id => [program]})

      programs = ListProviderPrograms.execute(provider_id)

      assert length(programs) == 1
      assert Enum.at(programs, 0).title == "Single Program"
    end

    test "programs include free and sold out variations" do
      provider_id = "550e8400-e29b-41d4-a716-446655440005"

      free_program = %Program{
        id: "660e8400-e29b-41d4-a716-446655440007",
        title: "Community Event",
        description: "Free community event",
        category: "education",
        schedule: "Sun 2-4pm",
        age_range: "All ages",
        price: Decimal.new("0.00"),
        pricing_period: "free",
        spots_available: 50,
        icon_path: nil,
        inserted_at: ~U[2025-01-07 08:00:00Z],
        updated_at: ~U[2025-01-07 08:00:00Z]
      }

      sold_out_program = %Program{
        id: "660e8400-e29b-41d4-a716-446655440008",
        title: "Popular Camp",
        description: "Fully booked camp",
        category: "sports",
        schedule: "Jul 1-15",
        age_range: "8-14 years",
        price: Decimal.new("500.00"),
        pricing_period: "per week",
        spots_available: 0,
        icon_path: "/images/icons/camp.svg",
        inserted_at: ~U[2025-01-08 14:00:00Z],
        updated_at: ~U[2025-01-08 14:00:00Z]
      }

      Process.put(:mock_provider_programs, %{
        provider_id => [free_program, sold_out_program]
      })

      programs = ListProviderPrograms.execute(provider_id)

      assert length(programs) == 2

      free = Enum.find(programs, &(&1.title == "Community Event"))
      assert free.price == Decimal.new("0.00")
      assert Program.free?(free)

      sold_out = Enum.find(programs, &(&1.title == "Popular Camp"))
      assert sold_out.spots_available == 0
      assert Program.sold_out?(sold_out)
    end
  end
end
