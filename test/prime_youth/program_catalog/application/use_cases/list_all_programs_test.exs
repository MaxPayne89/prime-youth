defmodule KlassHero.ProgramCatalog.Application.UseCases.ListAllProgramsTest do
  @moduledoc """
  Tests for the ListAllPrograms use case.

  This test suite verifies the use case orchestration logic without testing
  repository implementation details. We use a mock repository to focus on
  use case behavior.

  Test Coverage:
  - T045: Returns list of programs when repository succeeds
  - T046: Returns empty list when no programs exist
  """

  use ExUnit.Case, async: true

  alias KlassHero.ProgramCatalog.Application.UseCases.ListAllPrograms
  alias KlassHero.ProgramCatalog.Domain.Models.Program

  # Mock repository for testing
  defmodule MockRepository do
    @moduledoc false
    @behaviour KlassHero.ProgramCatalog.Domain.Ports.ForListingPrograms

    def list_all_programs do
      # This will be overridden by setting process dictionary in tests
      case Process.get(:mock_repository_response) do
        nil -> []
        response -> response
      end
    end

    def get_by_id(_id) do
      # This mock is not used in these tests, but required by the behavior
      {:error, :not_implemented}
    end

    def list_programs_paginated(_limit, _cursor) do
      # This mock is not used in these tests, but required by the behavior
      {:error, :not_implemented}
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
      Process.delete(:mock_repository_response)
    end)

    :ok
  end

  describe "execute/0" do
    # T045: Returns list of programs when repository succeeds
    test "returns list of programs when repository succeeds with valid programs" do
      program1 = %Program{
        id: "550e8400-e29b-41d4-a716-446655440001",
        title: "Soccer Stars",
        description: "Learn soccer fundamentals in a fun environment",
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
        id: "550e8400-e29b-41d4-a716-446655440002",
        title: "Art Adventure",
        description: "Explore creativity through painting and sculpture",
        schedule: "Tue-Thu 4-6pm",
        age_range: "7-12 years",
        price: Decimal.new("120.00"),
        pricing_period: "per month",
        spots_available: 8,
        icon_path: "/images/icons/art.svg",
        inserted_at: ~U[2025-01-02 10:00:00Z],
        updated_at: ~U[2025-01-02 10:00:00Z]
      }

      Process.put(:mock_repository_response, [program1, program2])

      programs = ListAllPrograms.execute()

      assert length(programs) == 2
      assert Enum.at(programs, 0) == program1
      assert Enum.at(programs, 1) == program2
    end

    # T046: Returns empty list when no programs exist
    test "returns empty list when no programs exist in repository" do
      Process.put(:mock_repository_response, [])

      programs = ListAllPrograms.execute()

      assert programs == []
    end

    test "handles repository returning multiple valid programs in correct order" do
      program1 = %Program{
        id: "550e8400-e29b-41d4-a716-446655440003",
        title: "Zebra Zone",
        description: "Wildlife education program",
        schedule: "Fri 2-4pm",
        age_range: "5-8 years",
        price: Decimal.new("100.00"),
        pricing_period: "per session",
        spots_available: 15,
        icon_path: nil,
        inserted_at: ~U[2025-01-03 09:00:00Z],
        updated_at: ~U[2025-01-03 09:00:00Z]
      }

      program2 = %Program{
        id: "550e8400-e29b-41d4-a716-446655440004",
        title: "Art Club",
        description: "Creative arts exploration",
        schedule: "Mon 3-5pm",
        age_range: "6-9 years",
        price: Decimal.new("80.00"),
        pricing_period: "per session",
        spots_available: 10,
        icon_path: "/images/icons/paint.svg",
        inserted_at: ~U[2025-01-04 11:00:00Z],
        updated_at: ~U[2025-01-04 11:00:00Z]
      }

      Process.put(:mock_repository_response, [program2, program1])

      programs = ListAllPrograms.execute()

      assert length(programs) == 2
      assert Enum.at(programs, 0).title == "Art Club"
      assert Enum.at(programs, 1).title == "Zebra Zone"
    end

    test "handles programs with edge case values (free program, sold out)" do
      free_program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440005",
        title: "Community Service",
        description: "Give back to the community",
        schedule: "Sat 10am-12pm",
        age_range: "12-18 years",
        price: Decimal.new("0.00"),
        pricing_period: "free",
        spots_available: 20,
        icon_path: nil,
        inserted_at: ~U[2025-01-05 08:00:00Z],
        updated_at: ~U[2025-01-05 08:00:00Z]
      }

      sold_out_program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440006",
        title: "Popular Camp",
        description: "High-demand summer camp",
        schedule: "Jun 15-20",
        age_range: "8-14 years",
        price: Decimal.new("500.00"),
        pricing_period: "per week",
        spots_available: 0,
        icon_path: "/images/icons/camp.svg",
        inserted_at: ~U[2025-01-06 14:00:00Z],
        updated_at: ~U[2025-01-06 14:00:00Z]
      }

      Process.put(:mock_repository_response, [free_program, sold_out_program])

      programs = ListAllPrograms.execute()

      assert length(programs) == 2

      free = Enum.find(programs, &(&1.title == "Community Service"))
      assert free.price == Decimal.new("0.00")
      assert free.spots_available == 20

      sold_out = Enum.find(programs, &(&1.title == "Popular Camp"))
      assert sold_out.price == Decimal.new("500.00")
      assert sold_out.spots_available == 0
    end
  end
end
