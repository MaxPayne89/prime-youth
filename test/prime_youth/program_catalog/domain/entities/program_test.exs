defmodule PrimeYouth.ProgramCatalog.Domain.Entities.ProgramTest do
  use ExUnit.Case, async: true

  alias PrimeYouth.ProgramCatalog.Domain.Entities.Program

  alias PrimeYouth.ProgramCatalog.Domain.ValueObjects.{
    AgeRange,
    ApprovalStatus,
    Pricing,
    ProgramCategory
  }

  describe "new/1" do
    test "creates program with valid attributes" do
      attrs = %{
        id: Ecto.UUID.generate(),
        title: "Summer Soccer Camp",
        description: "Learn soccer fundamentals in a fun summer environment.",
        provider_id: Ecto.UUID.generate(),
        category: ProgramCategory.new("sports"),
        secondary_categories: [],
        age_range: AgeRange.new(8, 12),
        capacity: 20,
        current_enrollment: 0,
        pricing: Pricing.new(250.00, "USD", "program", false),
        status: ApprovalStatus.draft(),
        is_prime_youth: false,
        featured: false
      }

      assert {:ok, %Program{} = program} = Program.new(attrs)
      assert program.title == "Summer Soccer Camp"
      assert program.capacity == 20
      assert program.current_enrollment == 0
    end

    test "requires title" do
      attrs = %{
        description: "Test description that is long enough for validation.",
        provider_id: Ecto.UUID.generate(),
        category: ProgramCategory.new("sports"),
        age_range: AgeRange.new(8, 12),
        capacity: 20,
        pricing: Pricing.new(250.00, "USD", "program", false)
      }

      assert {:error, {:missing_required_fields, fields}} = Program.new(attrs)
      assert :title in fields
    end

    test "title must be between 3 and 200 characters" do
      attrs = valid_attrs()

      # Too short
      assert {:error, :title_too_short} = Program.new(Map.put(attrs, :title, "ab"))

      # Too long
      long_title = String.duplicate("a", 201)
      assert {:error, :title_too_long} = Program.new(Map.put(attrs, :title, long_title))
    end

    test "description must be between 10 and 5000 characters" do
      attrs = valid_attrs()

      # Too short
      assert {:error, :description_too_short} = Program.new(Map.put(attrs, :description, "short"))

      # Too long
      long_desc = String.duplicate("a", 5001)

      assert {:error, :description_too_long} =
               Program.new(Map.put(attrs, :description, long_desc))
    end

    test "capacity must be greater than 0" do
      attrs = valid_attrs()

      assert {:error, :invalid_capacity} = Program.new(Map.put(attrs, :capacity, 0))
      assert {:error, :invalid_capacity} = Program.new(Map.put(attrs, :capacity, -1))
    end

    test "current_enrollment must be non-negative" do
      attrs = valid_attrs()

      assert {:error, :negative_enrollment} =
               Program.new(Map.put(attrs, :current_enrollment, -1))
    end

    test "current_enrollment cannot exceed capacity" do
      attrs = valid_attrs() |> Map.merge(%{capacity: 10, current_enrollment: 15})

      assert {:error, :enrollment_exceeds_capacity} = Program.new(attrs)
    end

    test "requires valid provider_id" do
      attrs = valid_attrs() |> Map.delete(:provider_id)

      assert {:error, {:missing_required_fields, fields}} = Program.new(attrs)
      assert :provider_id in fields
    end

    test "requires category" do
      attrs = valid_attrs() |> Map.delete(:category)

      assert {:error, {:missing_required_fields, fields}} = Program.new(attrs)
      assert :category in fields
    end

    test "secondary_categories limited to 3" do
      attrs = valid_attrs()

      # 3 categories is ok
      secondary = [
        ProgramCategory.new("arts"),
        ProgramCategory.new("stem"),
        ProgramCategory.new("leadership")
      ]

      assert {:ok, _program} = Program.new(Map.put(attrs, :secondary_categories, secondary))

      # 4 categories should fail
      secondary_too_many = secondary ++ [ProgramCategory.new("outdoor")]

      assert {:error, :too_many_secondary_categories} =
               Program.new(Map.put(attrs, :secondary_categories, secondary_too_many))
    end

    test "defaults is_prime_youth to false" do
      attrs = valid_attrs() |> Map.delete(:is_prime_youth)

      assert {:ok, program} = Program.new(attrs)
      assert program.is_prime_youth == false
    end

    test "defaults featured to false" do
      attrs = valid_attrs() |> Map.delete(:featured)

      assert {:ok, program} = Program.new(attrs)
      assert program.featured == false
    end

    test "defaults status to draft" do
      attrs = valid_attrs() |> Map.delete(:status)

      assert {:ok, program} = Program.new(attrs)
      assert program.status == ApprovalStatus.draft()
    end
  end

  describe "business rules" do
    test "external provider programs require approval" do
      attrs =
        valid_attrs() |> Map.merge(%{is_prime_youth: false, status: ApprovalStatus.draft()})

      assert {:ok, program} = Program.new(attrs)
      refute program.is_prime_youth
      assert program.status == ApprovalStatus.draft()
    end

    test "prime youth programs can be approved directly" do
      attrs =
        valid_attrs() |> Map.merge(%{is_prime_youth: true, status: ApprovalStatus.approved()})

      assert {:ok, program} = Program.new(attrs)
      assert program.is_prime_youth
      assert program.status == ApprovalStatus.approved()
    end

    test "archived programs have archived_at timestamp" do
      attrs = valid_attrs() |> Map.put(:archived_at, ~U[2025-01-01 12:00:00Z])

      assert {:ok, program} = Program.new(attrs)
      assert program.archived_at == ~U[2025-01-01 12:00:00Z]
    end

    test "active programs have nil archived_at" do
      attrs = valid_attrs()

      assert {:ok, program} = Program.new(attrs)
      assert is_nil(program.archived_at)
    end
  end

  # Helper functions

  defp valid_attrs do
    %{
      id: Ecto.UUID.generate(),
      title: "Summer Soccer Camp",
      description: "Learn soccer fundamentals in a fun and engaging summer environment.",
      provider_id: Ecto.UUID.generate(),
      category: ProgramCategory.new("sports"),
      secondary_categories: [],
      age_range: AgeRange.new(8, 12),
      capacity: 20,
      current_enrollment: 0,
      pricing: Pricing.new(250.00, "USD", "program", false),
      status: ApprovalStatus.draft(),
      is_prime_youth: false,
      featured: false,
      archived_at: nil
    }
  end
end
