defmodule KlassHero.ProgramCatalog.Domain.Models.ProgramTest do
  use ExUnit.Case, async: true

  alias KlassHero.ProgramCatalog.Domain.Models.Program

  # T017: Write domain model test: valid program creation
  describe "valid?/1 with valid program" do
    test "returns true for a program with all required fields" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440000",
        title: "Summer Soccer Camp",
        description: "Fun soccer activities for kids",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("150.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      assert Program.valid?(program)
    end

    test "returns true for a program with optional fields present" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440001",
        title: "Art Workshop",
        description: "Creative art activities",
        schedule: "Saturdays 10am-2pm",
        age_range: "8-12 years",
        price: Decimal.new("75.50"),
        pricing_period: "per session",
        spots_available: 15,
        gradient_class: "gradient-blue",
        icon_path: "/images/art-icon.svg",
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      assert Program.valid?(program)
    end

    test "returns true for a free program (price = 0)" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440002",
        title: "Community Sports Day",
        description: "Free sports activities for all",
        schedule: "Sunday 2pm-5pm",
        age_range: "5-15 years",
        price: Decimal.new("0"),
        pricing_period: "free event",
        spots_available: 50
      }

      assert Program.valid?(program)
    end

    test "returns true for a sold-out program (spots_available = 0)" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440003",
        title: "Popular Dance Class",
        description: "High-demand dance instruction",
        schedule: "Tuesdays 4pm-5pm",
        age_range: "7-9 years",
        price: Decimal.new("120.00"),
        pricing_period: "per month",
        spots_available: 0
      }

      assert Program.valid?(program)
    end
  end

  # T018: Write domain model test: title validation (empty, max 100 chars)
  describe "valid?/1 with invalid title" do
    test "returns false when title is empty string" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440004",
        title: "",
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      refute Program.valid?(program)
    end

    test "returns false when title is only whitespace" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440005",
        title: "   ",
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      refute Program.valid?(program)
    end

    test "returns false when title exceeds 100 characters" do
      long_title = String.duplicate("a", 101)

      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440006",
        title: long_title,
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      refute Program.valid?(program)
    end

    test "returns true when title is exactly 100 characters" do
      exact_title = String.duplicate("a", 100)

      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440007",
        title: exact_title,
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      assert Program.valid?(program)
    end
  end

  # T019: Write domain model test: description validation (empty, max 500 chars)
  describe "valid?/1 with invalid description" do
    test "returns false when description is empty string" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440008",
        title: "Valid Title",
        description: "",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      refute Program.valid?(program)
    end

    test "returns false when description is only whitespace" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440009",
        title: "Valid Title",
        description: "   ",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      refute Program.valid?(program)
    end

    test "returns false when description exceeds 500 characters" do
      long_description = String.duplicate("a", 501)

      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440010",
        title: "Valid Title",
        description: long_description,
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      refute Program.valid?(program)
    end

    test "returns true when description is exactly 500 characters" do
      exact_description = String.duplicate("a", 500)

      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440011",
        title: "Valid Title",
        description: exact_description,
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      assert Program.valid?(program)
    end
  end

  # T020: Write domain model test: price validation (≥ 0, allows $0)
  describe "valid?/1 with invalid price" do
    test "returns false when price is negative" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440012",
        title: "Valid Title",
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("-10.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      refute Program.valid?(program)
    end

    test "returns true when price is exactly 0" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440013",
        title: "Valid Title",
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("0"),
        pricing_period: "free",
        spots_available: 20
      }

      assert Program.valid?(program)
    end

    test "returns true when price is a small positive value" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440014",
        title: "Valid Title",
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("0.01"),
        pricing_period: "per session",
        spots_available: 20
      }

      assert Program.valid?(program)
    end
  end

  # T021: Write domain model test: spots_available validation (≥ 0)
  describe "valid?/1 with invalid spots_available" do
    test "returns false when spots_available is negative" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440015",
        title: "Valid Title",
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: -1
      }

      refute Program.valid?(program)
    end

    test "returns true when spots_available is exactly 0" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440016",
        title: "Valid Title",
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 0
      }

      assert Program.valid?(program)
    end

    test "returns true when spots_available is positive" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440017",
        title: "Valid Title",
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 100
      }

      assert Program.valid?(program)
    end
  end

  # T022: Write domain model test: sold_out?/1 helper
  describe "sold_out?/1" do
    test "returns true when spots_available is 0" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440018",
        title: "Sold Out Program",
        description: "This program is sold out",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 0
      }

      assert Program.sold_out?(program)
    end

    test "returns false when spots_available is greater than 0" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440019",
        title: "Available Program",
        description: "This program has spots",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 1
      }

      refute Program.sold_out?(program)
    end

    test "returns false when spots_available is large" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440020",
        title: "Popular Program",
        description: "Many spots available",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 100
      }

      refute Program.sold_out?(program)
    end
  end

  # T024: Write domain model test: new/1 constructor with valid data
  describe "new/1 constructor" do
    test "creates a valid program with all required fields" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440100",
        title: "Summer Soccer Camp",
        description: "Fun soccer activities for kids",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("150.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      assert {:ok, program} = Program.new(attrs)
      assert program.id == "550e8400-e29b-41d4-a716-446655440100"
      assert program.title == "Summer Soccer Camp"
      assert program.description == "Fun soccer activities for kids"
      assert program.schedule == "Mon-Fri 9am-12pm"
      assert program.age_range == "6-10 years"
      assert Decimal.equal?(program.price, Decimal.new("150.00"))
      assert program.pricing_period == "per week"
      assert program.spots_available == 20
    end

    test "creates a valid free program (price = 0)" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440101",
        title: "Community Sports Day",
        description: "Free sports activities for all",
        schedule: "Sunday 2pm-5pm",
        age_range: "5-15 years",
        price: Decimal.new("0"),
        pricing_period: "free event",
        spots_available: 50
      }

      assert {:ok, program} = Program.new(attrs)
      assert Decimal.equal?(program.price, Decimal.new("0"))
      assert Program.free?(program)
    end

    test "creates a valid sold-out program (spots = 0)" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440102",
        title: "Popular Dance Class",
        description: "High-demand dance instruction",
        schedule: "Tuesdays 4pm-5pm",
        age_range: "7-9 years",
        price: Decimal.new("120.00"),
        pricing_period: "per month",
        spots_available: 0
      }

      assert {:ok, program} = Program.new(attrs)
      assert program.spots_available == 0
      assert Program.sold_out?(program)
    end

    test "rejects empty title" do
      attrs = %{
        id: "1",
        title: "",
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      assert {:error, errors} = Program.new(attrs)
      assert "Title cannot be empty" in errors
    end

    test "rejects whitespace-only title" do
      attrs = %{
        id: "1",
        title: "   ",
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      assert {:error, errors} = Program.new(attrs)
      assert "Title cannot be empty" in errors
    end

    test "rejects title longer than 100 characters" do
      long_title = String.duplicate("a", 101)

      attrs = %{
        id: "1",
        title: long_title,
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      assert {:error, errors} = Program.new(attrs)
      assert "Title must be 100 characters or less" in errors
    end

    test "accepts title exactly 100 characters" do
      exact_title = String.duplicate("a", 100)

      attrs = %{
        id: "1",
        title: exact_title,
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      assert {:ok, _program} = Program.new(attrs)
    end

    test "rejects empty description" do
      attrs = %{
        id: "1",
        title: "Valid Title",
        description: "",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      assert {:error, errors} = Program.new(attrs)
      assert "Description cannot be empty" in errors
    end

    test "rejects whitespace-only description" do
      attrs = %{
        id: "1",
        title: "Valid Title",
        description: "   ",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      assert {:error, errors} = Program.new(attrs)
      assert "Description cannot be empty" in errors
    end

    test "rejects description longer than 500 characters" do
      long_description = String.duplicate("a", 501)

      attrs = %{
        id: "1",
        title: "Valid Title",
        description: long_description,
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      assert {:error, errors} = Program.new(attrs)
      assert "Description must be 500 characters or less" in errors
    end

    test "accepts description exactly 500 characters" do
      exact_description = String.duplicate("a", 500)

      attrs = %{
        id: "1",
        title: "Valid Title",
        description: exact_description,
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      assert {:ok, _program} = Program.new(attrs)
    end

    test "rejects negative price" do
      attrs = %{
        id: "1",
        title: "Valid Title",
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("-10.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      assert {:error, errors} = Program.new(attrs)
      assert "Price cannot be negative" in errors
    end

    test "rejects negative spots_available" do
      attrs = %{
        id: "1",
        title: "Valid Title",
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: -5
      }

      assert {:error, errors} = Program.new(attrs)
      assert "Spots available cannot be negative" in errors
    end

    test "rejects empty schedule" do
      attrs = %{
        id: "1",
        title: "Valid Title",
        description: "Valid description",
        schedule: "",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      assert {:error, errors} = Program.new(attrs)
      assert "Schedule cannot be empty" in errors
    end

    test "rejects empty age_range" do
      attrs = %{
        id: "1",
        title: "Valid Title",
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      assert {:error, errors} = Program.new(attrs)
      assert "Age range cannot be empty" in errors
    end

    test "rejects empty pricing_period" do
      attrs = %{
        id: "1",
        title: "Valid Title",
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "",
        spots_available: 20
      }

      assert {:error, errors} = Program.new(attrs)
      assert "Pricing period cannot be empty" in errors
    end

    test "returns multiple errors for multiple invalid fields" do
      attrs = %{
        id: "1",
        title: "",
        description: "",
        schedule: "",
        age_range: "",
        price: Decimal.new("-100.00"),
        pricing_period: "",
        spots_available: -5
      }

      assert {:error, errors} = Program.new(attrs)
      assert "Title cannot be empty" in errors
      assert "Description cannot be empty" in errors
      assert "Schedule cannot be empty" in errors
      assert "Age range cannot be empty" in errors
      assert "Pricing period cannot be empty" in errors
      assert "Price cannot be negative" in errors
      assert "Spots available cannot be negative" in errors
      assert length(errors) == 7
    end

    test "rejects non-string title" do
      attrs = %{
        id: "1",
        title: 123,
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      assert {:error, errors} = Program.new(attrs)
      assert "Title must be a string" in errors
    end

    test "rejects non-Decimal price" do
      attrs = %{
        id: "1",
        title: "Valid Title",
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: 100.00,
        pricing_period: "per week",
        spots_available: 20
      }

      assert {:error, errors} = Program.new(attrs)
      assert "Price must be a Decimal" in errors
    end

    test "rejects non-integer spots_available" do
      attrs = %{
        id: "1",
        title: "Valid Title",
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20.5
      }

      assert {:error, errors} = Program.new(attrs)
      assert "Spots available must be an integer" in errors
    end
  end

  # T023: Write domain model test: free?/1 helper
  describe "free?/1" do
    test "returns true when price is 0" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440021",
        title: "Free Program",
        description: "This program is free",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("0"),
        pricing_period: "free",
        spots_available: 50
      }

      assert Program.free?(program)
    end

    test "returns true when price is 0.00" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440022",
        title: "Free Event",
        description: "Free community event",
        schedule: "Saturday 10am-2pm",
        age_range: "5-15 years",
        price: Decimal.new("0.00"),
        pricing_period: "free",
        spots_available: 100
      }

      assert Program.free?(program)
    end

    test "returns false when price is greater than 0" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440023",
        title: "Paid Program",
        description: "This program has a fee",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("0.01"),
        pricing_period: "per session",
        spots_available: 20
      }

      refute Program.free?(program)
    end

    test "returns false when price is a typical positive value" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440024",
        title: "Premium Program",
        description: "Premium activities",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("150.00"),
        pricing_period: "per week",
        spots_available: 15
      }

      refute Program.free?(program)
    end
  end

  # T068: Domain model type enforcement tests for new/1
  describe "new/1 with type validation" do
    # T069: Reject non-Decimal price with clear error
    test "rejects non-Decimal price with clear error message" do
      attrs = %{
        id: "test-id-069",
        title: "Valid Title",
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: "100.00",
        # String instead of Decimal
        pricing_period: "per week",
        spots_available: 20
      }

      {:error, errors} = Program.new(attrs)

      assert "Price must be a Decimal" in errors
    end

    # T070: Reject non-integer spots_available
    test "rejects non-integer spots_available with clear error" do
      attrs = %{
        id: "test-id-070",
        title: "Valid Title",
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: "20"
        # String instead of integer
      }

      {:error, errors} = Program.new(attrs)

      assert "Spots available must be an integer" in errors
    end

    # T071: Reject non-string title
    test "rejects non-string title with clear error" do
      attrs = %{
        id: "test-id-071",
        title: 123,
        # Integer instead of string
        description: "Valid description",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      {:error, errors} = Program.new(attrs)

      assert "Title must be a string" in errors
    end

    # T072: Reject non-string description
    test "rejects non-string description with clear error" do
      attrs = %{
        id: "test-id-072",
        title: "Valid Title",
        description: [:invalid, :type],
        # List instead of string
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      {:error, errors} = Program.new(attrs)

      assert "Description must be a string" in errors
    end

    # T073: Reject non-string schedule
    test "rejects non-string schedule with clear error" do
      attrs = %{
        id: "test-id-073",
        title: "Valid Title",
        description: "Valid description",
        schedule: %{day: "Monday"},
        # Map instead of string
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      {:error, errors} = Program.new(attrs)

      assert "Schedule must be a string" in errors
    end

    # T074: Type validation occurs before business rule validation
    test "type errors are caught before business rule validation" do
      attrs = %{
        id: "test-id-074",
        title: 123,
        # Type error
        description: "",
        # Business rule error (empty)
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: "invalid",
        # Type error
        pricing_period: "per week",
        spots_available: -5
        # Business rule error (negative)
      }

      {:error, errors} = Program.new(attrs)

      # Type errors should be reported
      assert "Title must be a string" in errors
      assert "Price must be a Decimal" in errors

      # Business rule errors may or may not be reported
      # (depends on implementation - type errors might short-circuit)
    end

    # T075: Accept valid types with correct business rules
    test "accepts valid types with correct business rules" do
      attrs = %{
        id: "test-id-075",
        title: "Valid Program",
        description: "Valid description that meets length requirements",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("150.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      assert {:ok, %Program{}} = Program.new(attrs)
    end

    # T076: Accept edge case valid types (boundary values)
    test "accepts boundary value types correctly" do
      attrs = %{
        id: "test-id-076",
        title: "A",
        # Minimum valid length after trim
        description: "B",
        # Minimum valid length after trim
        schedule: "TBD",
        age_range: "0-99",
        price: Decimal.new("0"),
        # Free program
        pricing_period: "free",
        spots_available: 0
        # Sold out
      }

      assert {:ok, %Program{}} = Program.new(attrs)
    end
  end
end
