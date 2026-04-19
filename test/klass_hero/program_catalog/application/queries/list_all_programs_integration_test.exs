defmodule KlassHero.ProgramCatalog.Application.Queries.ListAllProgramsIntegrationTest do
  @moduledoc """
  Integration tests for the ListAllPrograms use case.

  These tests verify the COMPLETE data flow through all architectural layers:
  Use Case → Read Repository → Database → DTO Mapper → ProgramListing

  Unlike the unit tests (list_all_programs_test.exs) which use mocks,
  these integration tests use the REAL read repository implementation to catch
  bugs that can only be detected through actual system integration:

  - Repository returns invalid DTOs (mapper bugs)
  - Repository returns nil instead of empty list
  - Compile-time configuration resolves repository correctly
  - Type mismatches between layers
  - Database constraints and migrations

  Test Coverage:
  - T049: Returns valid ProgramListing DTOs from real repository
  - T050: Returns empty list when database is empty
  - T051: Returns programs in alphabetical order by title
  - T052: Configuration injection resolves repository correctly
  - T053: Handles edge cases (free programs, premium programs)
  - T054: All returned listings satisfy DTO contracts
  """

  # async: false is REQUIRED because this test modifies global Application config
  # which is not process-safe and can interfere with parallel tests
  use KlassHero.DataCase, async: false

  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramListingsRepository
  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramListingSchema
  alias KlassHero.ProgramCatalog.Application.Queries.ListAllPrograms
  alias KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListing
  alias KlassHero.Repo

  setup do
    # Clean database first (async: false tests share state)
    Repo.delete_all(ProgramListingSchema)
    :ok
  end

  describe "execute/0 - Integration Tests" do
    # T049: Returns valid ProgramListing DTOs from real repository
    test "returns valid ProgramListing DTOs from real repository" do
      insert_listing(%{
        title: "Soccer Camp",
        description: "Fun soccer for kids",
        age_range: "6-12 years",
        price: Decimal.new("150.00"),
        pricing_period: "per week"
      })

      insert_listing(%{
        title: "Art Class",
        description: "Creative art activities",
        age_range: "8-14 years",
        price: Decimal.new("75.00"),
        pricing_period: "per month"
      })

      programs = ListAllPrograms.execute()

      assert length(programs) == 2
      assert Enum.all?(programs, &match?(%ProgramListing{}, &1))

      assert Enum.all?(programs, fn listing ->
               match?(%ProgramListing{}, listing) &&
                 is_binary(listing.id) &&
                 is_binary(listing.title) && listing.title != "" &&
                 is_binary(listing.description) && listing.description != "" &&
                 is_binary(listing.age_range) && listing.age_range != "" &&
                 match?(%Decimal{}, listing.price) &&
                 is_binary(listing.pricing_period) && listing.pricing_period != ""
             end)

      soccer_camp = Enum.find(programs, &(&1.title == "Soccer Camp"))
      assert soccer_camp.description == "Fun soccer for kids"
      assert soccer_camp.age_range == "6-12 years"
      assert Decimal.equal?(soccer_camp.price, Decimal.new("150.00"))
      assert soccer_camp.pricing_period == "per week"

      art_class = Enum.find(programs, &(&1.title == "Art Class"))
      assert art_class.description == "Creative art activities"
      assert Decimal.equal?(art_class.price, Decimal.new("75.00"))
    end

    # T050: Returns empty list when database is empty
    test "returns empty list when database is empty" do
      Repo.delete_all(ProgramListingSchema)

      programs = ListAllPrograms.execute()

      assert programs == []
      assert is_list(programs)
    end

    # T051: Returns programs in alphabetical order by title
    test "returns programs in alphabetical order by title" do
      insert_listing(%{
        title: "Zebra Camp",
        description: "Wildlife education",
        age_range: "6-12 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week"
      })

      insert_listing(%{
        title: "Art Class",
        description: "Creative activities",
        age_range: "6-12 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week"
      })

      insert_listing(%{
        title: "Music Lessons",
        description: "Learn instruments",
        age_range: "6-12 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week"
      })

      programs = ListAllPrograms.execute()

      titles = Enum.map(programs, & &1.title)
      assert titles == ["Art Class", "Music Lessons", "Zebra Camp"]
    end

    # T052: Configuration injection resolves repository correctly
    test "configuration injection resolves repository correctly" do
      config = Application.get_env(:klass_hero, :program_catalog)
      repository_module = config[:for_listing_program_summaries]

      assert repository_module ==
               ProgramListingsRepository

      insert_listing(%{
        title: "Test Program",
        description: "Description",
        age_range: "6-12 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week"
      })

      programs = ListAllPrograms.execute()

      assert length(programs) == 1
      assert List.first(programs).title == "Test Program"
    end

    # T053: Handles edge cases (free programs, premium programs)
    test "handles edge cases: free programs and premium programs" do
      insert_listing(%{
        title: "Free Community Service",
        description: "Give back to the community",
        age_range: "12-18 years",
        price: Decimal.new("0.00"),
        pricing_period: "free"
      })

      insert_listing(%{
        title: "Premium Camp",
        description: "High-demand summer camp",
        age_range: "8-14 years",
        price: Decimal.new("500.00"),
        pricing_period: "per week"
      })

      programs = ListAllPrograms.execute()

      assert length(programs) == 2

      free_program = Enum.find(programs, &(&1.title == "Free Community Service"))
      assert Decimal.equal?(free_program.price, Decimal.new("0.00"))

      premium_program = Enum.find(programs, &(&1.title == "Premium Camp"))
      assert Decimal.equal?(premium_program.price, Decimal.new("500.00"))
    end

    # T054: All returned listings satisfy DTO contracts
    test "all returned listings satisfy DTO contracts" do
      insert_listing(%{
        title: "Program A",
        description: "Description A",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week"
      })

      insert_listing(%{
        title: "Program B",
        description: "Description B",
        age_range: "8-12 years",
        price: Decimal.new("0.00"),
        pricing_period: "free"
      })

      programs = ListAllPrograms.execute()

      assert length(programs) == 2

      Enum.each(programs, fn listing ->
        assert is_binary(listing.id) && listing.id != ""
        assert is_binary(listing.title) && listing.title != ""
        assert is_binary(listing.description) && listing.description != ""
        assert is_binary(listing.age_range) && listing.age_range != ""
        assert match?(%Decimal{}, listing.price)
        assert is_binary(listing.pricing_period) && listing.pricing_period != ""

        assert match?(%DateTime{}, listing.inserted_at)
        assert match?(%DateTime{}, listing.updated_at)
      end)
    end

    test "handles multiple listings with varying optional fields" do
      insert_listing(%{
        title: "Program 1",
        description: "With all fields",
        age_range: "6-12 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week"
      })

      insert_listing(%{
        title: "Program 2",
        description: "With no optional fields",
        age_range: "6-12 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week"
      })

      programs = ListAllPrograms.execute()

      assert length(programs) == 2

      program1 = Enum.find(programs, &(&1.title == "Program 1"))
      refute Map.has_key?(program1, :icon_path)

      program2 = Enum.find(programs, &(&1.title == "Program 2"))
      refute Map.has_key?(program2, :icon_path)
    end
  end

  defp insert_listing(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    default_attrs = %{
      id: Ecto.UUID.generate(),
      category: "education",
      meeting_days: [],
      provider_id: Ecto.UUID.generate(),
      provider_verified: false,
      inserted_at: now,
      updated_at: now
    }

    merged = Map.merge(default_attrs, attrs)

    %ProgramListingSchema{}
    |> Ecto.Changeset.change(merged)
    |> Repo.insert!()
  end
end
