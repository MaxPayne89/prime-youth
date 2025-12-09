defmodule PrimeYouth.ProgramCatalog.Application.UseCases.ListAllProgramsTest do
  @moduledoc """
  Tests for the ListAllPrograms use case.

  This test suite verifies the use case orchestration logic without testing
  repository implementation details. We use a mock repository to focus on
  use case behavior.

  Test Coverage:
  - T045: Returns {:ok, programs} when repository succeeds
  - T046: Returns {:ok, []} when no programs exist
  - T047: Returns {:error, :database_error} when repository fails
  - T048: Propagates error without logging (domain purity)
  """

  use ExUnit.Case, async: true

  alias PrimeYouth.ProgramCatalog.Application.UseCases.ListAllPrograms
  alias PrimeYouth.ProgramCatalog.Domain.Models.Program

  # Mock repository for testing
  defmodule MockRepository do
    @moduledoc false
    @behaviour PrimeYouth.ProgramCatalog.Domain.Ports.ForListingPrograms

    def list_all_programs do
      # This will be overridden by setting process dictionary in tests
      case Process.get(:mock_repository_response) do
        nil -> {:ok, []}
        response -> response
      end
    end

    def get_by_id(_id) do
      # This mock is not used in these tests, but required by the behavior
      {:error, :not_implemented}
    end
  end

  setup do
    # Store original config
    original_config = Application.get_env(:prime_youth, :program_catalog)

    # Configure use case to use mock repository
    Application.put_env(:prime_youth, :program_catalog, repository: __MODULE__.MockRepository)

    on_exit(fn ->
      # Restore original config
      if original_config do
        Application.put_env(:prime_youth, :program_catalog, original_config)
      else
        Application.delete_env(:prime_youth, :program_catalog)
      end

      # Clean up process dictionary
      Process.delete(:mock_repository_response)
    end)

    :ok
  end

  describe "execute/0" do
    # T045: Returns {:ok, programs} when repository succeeds
    test "returns {:ok, programs} when repository succeeds with valid programs" do
      # Arrange: Create sample programs
      program1 = %Program{
        id: "550e8400-e29b-41d4-a716-446655440001",
        title: "Soccer Stars",
        description: "Learn soccer fundamentals in a fun environment",
        schedule: "Mon-Wed 3-5pm",
        age_range: "6-10 years",
        price: Decimal.new("150.00"),
        pricing_period: "per month",
        spots_available: 12,
        gradient_class: "bg-gradient-to-br from-green-400 to-blue-500",
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
        gradient_class: "bg-gradient-to-br from-purple-400 to-pink-500",
        icon_path: "/images/icons/art.svg",
        inserted_at: ~U[2025-01-02 10:00:00Z],
        updated_at: ~U[2025-01-02 10:00:00Z]
      }

      # Set mock to return programs
      Process.put(:mock_repository_response, {:ok, [program1, program2]})

      # Act: Execute use case
      result = ListAllPrograms.execute()

      # Assert: Verify successful response
      assert {:ok, programs} = result
      assert length(programs) == 2
      assert Enum.at(programs, 0) == program1
      assert Enum.at(programs, 1) == program2
    end

    # T046: Returns {:ok, []} when no programs exist
    test "returns {:ok, []} when no programs exist in repository" do
      # Arrange: Set mock to return empty list
      Process.put(:mock_repository_response, {:ok, []})

      # Act: Execute use case
      result = ListAllPrograms.execute()

      # Assert: Verify empty list response
      assert {:ok, []} = result
    end

    # T047: Returns {:error, :database_error} when repository fails
    test "returns {:error, :database_error} when repository fails" do
      # Arrange: Set mock to return database error
      Process.put(:mock_repository_response, {:error, :database_error})

      # Act: Execute use case
      result = ListAllPrograms.execute()

      # Assert: Verify error is propagated
      assert {:error, :database_error} = result
    end

    # T048: Propagates error without logging (domain purity)
    test "propagates error without logging (domain purity)" do
      import ExUnit.CaptureLog
      # Arrange: Set mock to return database error
      Process.put(:mock_repository_response, {:error, :database_error})

      # Capture any logs that might be emitted

      # Act: Execute use case and capture logs
      log_output =
        capture_log(fn ->
          result = ListAllPrograms.execute()
          assert {:error, :database_error} = result
        end)

      # Assert: Verify no logs were emitted (domain purity)
      # The use case should not log errors - that's the adapter's responsibility
      assert log_output == ""
    end

    test "handles repository returning multiple valid programs in correct order" do
      # Arrange: Create programs in non-alphabetical order
      program1 = %Program{
        id: "550e8400-e29b-41d4-a716-446655440003",
        title: "Zebra Zone",
        description: "Wildlife education program",
        schedule: "Fri 2-4pm",
        age_range: "5-8 years",
        price: Decimal.new("100.00"),
        pricing_period: "per session",
        spots_available: 15,
        gradient_class: "bg-gradient-to-br from-yellow-400 to-orange-500",
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
        gradient_class: nil,
        icon_path: "/images/icons/paint.svg",
        inserted_at: ~U[2025-01-04 11:00:00Z],
        updated_at: ~U[2025-01-04 11:00:00Z]
      }

      # Repository should return them in alphabetical order (Art Club, Zebra Zone)
      Process.put(:mock_repository_response, {:ok, [program2, program1]})

      # Act: Execute use case
      result = ListAllPrograms.execute()

      # Assert: Verify programs are returned in the order from repository
      assert {:ok, programs} = result
      assert length(programs) == 2
      # Use case should preserve repository ordering
      assert Enum.at(programs, 0).title == "Art Club"
      assert Enum.at(programs, 1).title == "Zebra Zone"
    end

    test "handles programs with edge case values (free program, sold out)" do
      # Arrange: Create programs with edge case values
      free_program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440005",
        title: "Community Service",
        description: "Give back to the community",
        schedule: "Sat 10am-12pm",
        age_range: "12-18 years",
        price: Decimal.new("0.00"),
        pricing_period: "free",
        spots_available: 20,
        gradient_class: "bg-gradient-to-br from-gray-400 to-gray-600",
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
        gradient_class: "bg-gradient-to-br from-red-400 to-orange-500",
        icon_path: "/images/icons/camp.svg",
        inserted_at: ~U[2025-01-06 14:00:00Z],
        updated_at: ~U[2025-01-06 14:00:00Z]
      }

      Process.put(:mock_repository_response, {:ok, [free_program, sold_out_program]})

      # Act: Execute use case
      result = ListAllPrograms.execute()

      # Assert: Verify both programs are returned correctly
      assert {:ok, programs} = result
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
