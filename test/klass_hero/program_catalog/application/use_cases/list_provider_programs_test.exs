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

  # async: false because setup mutates global Application config (:program_catalog),
  # which would race with concurrent tests that use the real repository
  use ExUnit.Case, async: false

  alias KlassHero.ProgramCatalog.Application.UseCases.ListProviderPrograms
  alias KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListing
  alias KlassHero.Shared.Domain.Types.Pagination.PageResult

  # Mock repository implementing the read port
  defmodule MockRepository do
    @moduledoc false
    @behaviour KlassHero.ProgramCatalog.Domain.Ports.ForListingProgramSummaries

    def list_all do
      []
    end

    def list_paginated(_limit, _cursor, _category) do
      {:ok, %PageResult{items: [], next_cursor: nil, has_more: false}}
    end

    def list_for_provider(provider_id) do
      case Process.get(:mock_provider_programs) do
        nil -> []
        programs_by_provider -> Map.get(programs_by_provider, provider_id, [])
      end
    end

    def get_by_id(_id) do
      {:error, :not_found}
    end
  end

  setup do
    # Store original config
    original_config = Application.get_env(:klass_hero, :program_catalog)

    # Configure use case to use mock repository
    Application.put_env(:klass_hero, :program_catalog,
      for_listing_program_summaries: __MODULE__.MockRepository
    )

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

      listing1 = %ProgramListing{
        id: "660e8400-e29b-41d4-a716-446655440001",
        title: "Soccer Stars",
        description: "Learn soccer fundamentals",
        category: "sports",
        meeting_days: ["Monday", "Wednesday"],
        age_range: "6-10 years",
        price: Decimal.new("150.00"),
        pricing_period: "per month",
        icon_path: "/images/icons/soccer.svg",
        provider_id: provider_id,
        inserted_at: ~U[2025-01-01 12:00:00Z],
        updated_at: ~U[2025-01-01 12:00:00Z]
      }

      listing2 = %ProgramListing{
        id: "660e8400-e29b-41d4-a716-446655440002",
        title: "Art Adventure",
        description: "Explore creativity",
        category: "arts",
        meeting_days: ["Tuesday", "Thursday"],
        age_range: "7-12 years",
        price: Decimal.new("120.00"),
        pricing_period: "per month",
        icon_path: "/images/icons/art.svg",
        provider_id: provider_id,
        inserted_at: ~U[2025-01-02 10:00:00Z],
        updated_at: ~U[2025-01-02 10:00:00Z]
      }

      Process.put(:mock_provider_programs, %{provider_id => [listing1, listing2]})

      programs = ListProviderPrograms.execute(provider_id)

      assert length(programs) == 2
      assert Enum.at(programs, 0) == listing1
      assert Enum.at(programs, 1) == listing2
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

      listing_z = %ProgramListing{
        id: "660e8400-e29b-41d4-a716-446655440003",
        title: "Zebra Club",
        description: "Wildlife education",
        category: "education",
        meeting_days: ["Friday"],
        age_range: "5-8 years",
        price: Decimal.new("100.00"),
        pricing_period: "per session",
        icon_path: nil,
        provider_id: provider_id,
        inserted_at: ~U[2025-01-03 09:00:00Z],
        updated_at: ~U[2025-01-03 09:00:00Z]
      }

      listing_a = %ProgramListing{
        id: "660e8400-e29b-41d4-a716-446655440004",
        title: "Art Class",
        description: "Creative arts",
        category: "arts",
        meeting_days: ["Monday"],
        age_range: "6-9 years",
        price: Decimal.new("80.00"),
        pricing_period: "per session",
        icon_path: "/images/icons/paint.svg",
        provider_id: provider_id,
        inserted_at: ~U[2025-01-04 11:00:00Z],
        updated_at: ~U[2025-01-04 11:00:00Z]
      }

      listing_m = %ProgramListing{
        id: "660e8400-e29b-41d4-a716-446655440005",
        title: "Music Camp",
        description: "Learn music",
        category: "music",
        meeting_days: ["Wednesday"],
        age_range: "8-14 years",
        price: Decimal.new("200.00"),
        pricing_period: "per month",
        icon_path: "/images/icons/music.svg",
        provider_id: provider_id,
        inserted_at: ~U[2025-01-05 08:00:00Z],
        updated_at: ~U[2025-01-05 08:00:00Z]
      }

      # Mock returns pre-sorted by title (as repository should)
      Process.put(:mock_provider_programs, %{
        provider_id => [listing_a, listing_m, listing_z]
      })

      programs = ListProviderPrograms.execute(provider_id)

      assert length(programs) == 3
      titles = Enum.map(programs, & &1.title)
      assert titles == ["Art Class", "Music Camp", "Zebra Club"]
    end

    test "handles provider with single program" do
      provider_id = "550e8400-e29b-41d4-a716-446655440004"

      listing = %ProgramListing{
        id: "660e8400-e29b-41d4-a716-446655440006",
        title: "Single Program",
        description: "Only one program",
        category: "education",
        meeting_days: ["Saturday"],
        age_range: "6-12 years",
        price: Decimal.new("50.00"),
        pricing_period: "per session",
        icon_path: nil,
        provider_id: provider_id,
        inserted_at: ~U[2025-01-06 10:00:00Z],
        updated_at: ~U[2025-01-06 10:00:00Z]
      }

      Process.put(:mock_provider_programs, %{provider_id => [listing]})

      programs = ListProviderPrograms.execute(provider_id)

      assert length(programs) == 1
      assert Enum.at(programs, 0).title == "Single Program"
    end

    test "programs include free and premium variations" do
      provider_id = "550e8400-e29b-41d4-a716-446655440005"

      free_listing = %ProgramListing{
        id: "660e8400-e29b-41d4-a716-446655440007",
        title: "Community Event",
        description: "Free community event",
        category: "education",
        meeting_days: ["Sunday"],
        age_range: "All ages",
        price: Decimal.new("0.00"),
        pricing_period: "free",
        icon_path: nil,
        provider_id: provider_id,
        inserted_at: ~U[2025-01-07 08:00:00Z],
        updated_at: ~U[2025-01-07 08:00:00Z]
      }

      premium_listing = %ProgramListing{
        id: "660e8400-e29b-41d4-a716-446655440008",
        title: "Popular Camp",
        description: "Fully booked camp",
        category: "sports",
        meeting_days: [],
        age_range: "8-14 years",
        price: Decimal.new("500.00"),
        pricing_period: "per week",
        icon_path: "/images/icons/camp.svg",
        provider_id: provider_id,
        inserted_at: ~U[2025-01-08 14:00:00Z],
        updated_at: ~U[2025-01-08 14:00:00Z]
      }

      Process.put(:mock_provider_programs, %{
        provider_id => [free_listing, premium_listing]
      })

      programs = ListProviderPrograms.execute(provider_id)

      assert length(programs) == 2

      free = Enum.find(programs, &(&1.title == "Community Event"))
      assert free.price == Decimal.new("0.00")

      premium = Enum.find(programs, &(&1.title == "Popular Camp"))
      assert premium.price == Decimal.new("500.00")
    end
  end
end
