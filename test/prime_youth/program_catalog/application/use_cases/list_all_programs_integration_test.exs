defmodule PrimeYouth.ProgramCatalog.Application.UseCases.ListAllProgramsIntegrationTest do
  @moduledoc """
  Integration tests for the ListAllPrograms use case.

  These tests verify the COMPLETE data flow through all architectural layers:
  Use Case → Repository → Database → Mapper → Domain Model

  Unlike the unit tests (list_all_programs_test.exs) which use mocks,
  these integration tests use the REAL repository implementation to catch
  bugs that can only be detected through actual system integration:

  - Repository returns invalid domain models (mapper bugs)
  - Repository returns nil instead of empty list
  - Configuration injection fails
  - Type mismatches between layers
  - Database constraints and migrations

  Test Coverage:
  - T049: Returns valid domain models from real repository
  - T050: Returns empty list when database is empty
  - T051: Returns programs in alphabetical order by title
  - T052: Configuration injection resolves repository correctly
  - T053: Handles edge cases (free programs, sold-out programs)
  - T054: All returned programs satisfy domain model contracts
  """

  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.ProgramCatalog.Application.UseCases.ListAllPrograms
  alias PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
  alias PrimeYouth.ProgramCatalog.Domain.Models.Program
  alias PrimeYouth.Repo

  # Ensure we're using the real repository for integration tests
  setup do
    # Store original config
    original_config = Application.get_env(:prime_youth, :program_catalog)

    # Ensure use case is configured to use the REAL repository
    Application.put_env(
      :prime_youth,
      :program_catalog,
      repository:
        PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepository
    )

    on_exit(fn ->
      # Restore original config
      if original_config do
        Application.put_env(:prime_youth, :program_catalog, original_config)
      else
        Application.delete_env(:prime_youth, :program_catalog)
      end
    end)

    :ok
  end

  describe "execute/0 - Integration Tests" do
    # T049: Returns valid domain models from real repository
    test "returns valid domain models from real repository" do
      # Arrange: Insert actual programs via the database
      insert_program(%{
        title: "Soccer Camp",
        description: "Fun soccer for kids",
        schedule: "Mon-Fri 9AM-12PM",
        age_range: "6-12 years",
        price: Decimal.new("150.00"),
        pricing_period: "per week",
        spots_available: 20
      })

      insert_program(%{
        title: "Art Class",
        description: "Creative art activities",
        schedule: "Saturdays 10AM-12PM",
        age_range: "8-14 years",
        price: Decimal.new("75.00"),
        pricing_period: "per month",
        spots_available: 15
      })

      # Act: Execute use case (no mocks - real repository)
      {:ok, programs} = ListAllPrograms.execute()

      # Assert: Verify domain model contracts
      assert length(programs) == 2
      assert Enum.all?(programs, &match?(%Program{}, &1))

      # Verify all programs are valid domain models
      assert Enum.all?(programs, fn program ->
               # Check struct type
               match?(%Program{}, program) &&
                 # Check required fields are present and valid
                 is_binary(program.id) &&
                 is_binary(program.title) && program.title != "" &&
                 is_binary(program.description) && program.description != "" &&
                 is_binary(program.schedule) && program.schedule != "" &&
                 is_binary(program.age_range) && program.age_range != "" &&
                 match?(%Decimal{}, program.price) &&
                 is_binary(program.pricing_period) && program.pricing_period != "" &&
                 is_integer(program.spots_available) && program.spots_available >= 0
             end)

      # Verify specific program data was correctly mapped
      soccer_camp = Enum.find(programs, &(&1.title == "Soccer Camp"))
      assert soccer_camp.description == "Fun soccer for kids"
      assert soccer_camp.schedule == "Mon-Fri 9AM-12PM"
      assert soccer_camp.age_range == "6-12 years"
      assert Decimal.equal?(soccer_camp.price, Decimal.new("150.00"))
      assert soccer_camp.pricing_period == "per week"
      assert soccer_camp.spots_available == 20

      art_class = Enum.find(programs, &(&1.title == "Art Class"))
      assert art_class.description == "Creative art activities"
      assert Decimal.equal?(art_class.price, Decimal.new("75.00"))
    end

    # T050: Returns empty list when database is empty
    test "returns empty list when database is empty" do
      # Arrange: Ensure database is empty
      Repo.delete_all(ProgramSchema)

      # Act: Execute use case
      {:ok, programs} = ListAllPrograms.execute()

      # Assert: Verify empty list is returned (not nil, not error)
      assert programs == []
      assert is_list(programs)
    end

    # T051: Returns programs in alphabetical order by title
    test "returns programs in alphabetical order by title" do
      # Arrange: Insert programs in non-alphabetical order
      insert_program(%{
        title: "Zebra Camp",
        description: "Wildlife education",
        schedule: "Mon-Fri",
        age_range: "6-12 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10
      })

      insert_program(%{
        title: "Art Class",
        description: "Creative activities",
        schedule: "Mon-Fri",
        age_range: "6-12 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10
      })

      insert_program(%{
        title: "Music Lessons",
        description: "Learn instruments",
        schedule: "Mon-Fri",
        age_range: "6-12 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10
      })

      # Act: Execute use case
      {:ok, programs} = ListAllPrograms.execute()

      # Assert: Verify programs are ordered alphabetically by title
      titles = Enum.map(programs, & &1.title)
      assert titles == ["Art Class", "Music Lessons", "Zebra Camp"]
    end

    # T052: Configuration injection resolves repository correctly
    test "configuration injection resolves repository correctly" do
      # Arrange: Verify config is set to the real repository
      config = Application.get_env(:prime_youth, :program_catalog)
      repository_module = config[:repository]

      assert repository_module ==
               PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepository

      # Insert a program to verify repository is actually being used
      insert_program(%{
        title: "Test Program",
        description: "Description",
        schedule: "Mon-Fri",
        age_range: "6-12 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10
      })

      # Act: Execute use case (should use configured repository)
      {:ok, programs} = ListAllPrograms.execute()

      # Assert: Verify program was retrieved via configured repository
      assert length(programs) == 1
      assert List.first(programs).title == "Test Program"
    end

    # T053: Handles edge cases (free programs, sold-out programs)
    test "handles edge cases: free programs and sold-out programs" do
      # Arrange: Create programs with edge case values
      insert_program(%{
        title: "Free Community Service",
        description: "Give back to the community",
        schedule: "Sat 10AM-12PM",
        age_range: "12-18 years",
        price: Decimal.new("0.00"),
        pricing_period: "free",
        spots_available: 20
      })

      insert_program(%{
        title: "Sold Out Camp",
        description: "High-demand summer camp",
        schedule: "Jun 15-20",
        age_range: "8-14 years",
        price: Decimal.new("500.00"),
        pricing_period: "per week",
        spots_available: 0
      })

      # Act: Execute use case
      {:ok, programs} = ListAllPrograms.execute()

      # Assert: Verify both programs are returned correctly
      assert length(programs) == 2

      free_program = Enum.find(programs, &(&1.title == "Free Community Service"))
      assert Decimal.equal?(free_program.price, Decimal.new("0.00"))
      assert free_program.spots_available == 20
      # Verify free? helper method works (domain model behavior)
      assert Program.free?(free_program)
      refute Program.sold_out?(free_program)

      sold_out_program = Enum.find(programs, &(&1.title == "Sold Out Camp"))
      assert Decimal.equal?(sold_out_program.price, Decimal.new("500.00"))
      assert sold_out_program.spots_available == 0
      # Verify sold_out? helper method works (domain model behavior)
      assert Program.sold_out?(sold_out_program)
      refute Program.free?(sold_out_program)
    end

    # T054: All returned programs satisfy domain model contracts
    test "all returned programs satisfy domain model contracts" do
      # Arrange: Insert various programs with different valid configurations
      insert_program(%{
        title: "Program A",
        description: "Description A",
        schedule: "Schedule A",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10,
        # Optional fields
        gradient_class: "custom-gradient",
        icon_path: "/custom/icon.svg"
      })

      insert_program(%{
        title: "Program B",
        description: "Description B",
        schedule: "Schedule B",
        age_range: "8-12 years",
        price: Decimal.new("0.00"),
        pricing_period: "free",
        spots_available: 0
        # Optional fields are nil
      })

      # Act: Execute use case
      {:ok, programs} = ListAllPrograms.execute()

      # Assert: Verify ALL programs satisfy domain contracts
      assert length(programs) == 2

      Enum.each(programs, fn program ->
        # Required fields must be non-nil and non-empty for strings
        assert is_binary(program.id) && program.id != ""
        assert is_binary(program.title) && program.title != ""
        assert is_binary(program.description) && program.description != ""
        assert is_binary(program.schedule) && program.schedule != ""
        assert is_binary(program.age_range) && program.age_range != ""
        assert match?(%Decimal{}, program.price)
        assert is_binary(program.pricing_period) && program.pricing_period != ""
        assert is_integer(program.spots_available) && program.spots_available >= 0

        # Optional fields can be nil
        if program.gradient_class, do: assert(is_binary(program.gradient_class))
        if program.icon_path, do: assert(is_binary(program.icon_path))

        # Timestamps should be set
        assert match?(%DateTime{}, program.inserted_at)
        assert match?(%DateTime{}, program.updated_at)
      end)
    end

    test "handles multiple programs with varying optional fields" do
      # Arrange: Create programs with different combinations of optional fields
      insert_program(%{
        title: "Program 1",
        description: "With all fields",
        schedule: "Mon-Fri",
        age_range: "6-12 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10,
        gradient_class: "gradient-1",
        icon_path: "/icon1.svg"
      })

      insert_program(%{
        title: "Program 2",
        description: "With no optional fields",
        schedule: "Mon-Fri",
        age_range: "6-12 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10
        # gradient_class and icon_path are nil
      })

      # Act: Execute use case
      {:ok, programs} = ListAllPrograms.execute()

      # Assert: Verify both programs are returned with correct optional field handling
      assert length(programs) == 2

      program1 = Enum.find(programs, &(&1.title == "Program 1"))
      assert program1.gradient_class == "gradient-1"
      assert program1.icon_path == "/icon1.svg"

      program2 = Enum.find(programs, &(&1.title == "Program 2"))
      assert program2.gradient_class == nil
      assert program2.icon_path == nil
    end
  end

  # Helper function to insert a complete valid program via ProgramSchema
  # This simulates actual database persistence and tests the full integration path
  defp insert_program(attrs) do
    default_attrs = %{
      id: Ecto.UUID.generate()
      # gradient_class and icon_path intentionally left as nil by default
      # to test optional field handling
    }

    attrs = Map.merge(default_attrs, attrs)

    %ProgramSchema{}
    |> ProgramSchema.changeset(attrs)
    |> Repo.insert!()
  end
end
