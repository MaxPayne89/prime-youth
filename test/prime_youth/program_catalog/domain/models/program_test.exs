defmodule KlassHero.ProgramCatalog.Domain.Models.ProgramTest do
  @moduledoc """
  Tests for the Program domain model.

  Note: Full field validation (length limits, category whitelist, etc.) is handled
  by the Ecto schema layer. The domain model provides simplified runtime invariant
  checks via valid?/1 and business logic helpers like sold_out?/1 and free?/1.
  """

  use ExUnit.Case, async: true

  alias KlassHero.ProgramCatalog.Domain.Models.Program

  # Helper to build valid program attrs
  defp valid_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        title: "Summer Soccer Camp",
        description: "Fun soccer activities for kids",
        category: "sports",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("150.00"),
        pricing_period: "per week",
        spots_available: 20
      },
      overrides
    )
  end

  describe "new/1 constructor" do
    test "creates a program from valid attributes" do
      attrs = valid_attrs()

      assert {:ok, program} = Program.new(attrs)
      assert program.id == "550e8400-e29b-41d4-a716-446655440000"
      assert program.title == "Summer Soccer Camp"
      assert program.description == "Fun soccer activities for kids"
      assert program.schedule == "Mon-Fri 9am-12pm"
      assert program.age_range == "6-10 years"
      assert Decimal.equal?(program.price, Decimal.new("150.00"))
      assert program.pricing_period == "per week"
      assert program.spots_available == 20
    end

    test "creates a free program (price = 0)" do
      attrs = valid_attrs(%{price: Decimal.new("0"), pricing_period: "free event"})

      assert {:ok, program} = Program.new(attrs)
      assert Decimal.equal?(program.price, Decimal.new("0"))
      assert Program.free?(program)
    end

    test "creates a sold-out program (spots = 0)" do
      attrs = valid_attrs(%{spots_available: 0})

      assert {:ok, program} = Program.new(attrs)
      assert program.spots_available == 0
      assert Program.sold_out?(program)
    end

    test "includes optional fields when present" do
      now = DateTime.utc_now()

      attrs =
        valid_attrs(%{
          icon_path: "/images/soccer.svg",
          lock_version: 1,
          inserted_at: now,
          updated_at: now
        })

      assert {:ok, program} = Program.new(attrs)
      assert program.icon_path == "/images/soccer.svg"
      assert program.lock_version == 1
      assert program.inserted_at == now
      assert program.updated_at == now
    end
  end

  describe "new!/1 constructor" do
    test "creates a program from valid attributes" do
      attrs = valid_attrs()

      program = Program.new!(attrs)

      assert %Program{} = program
      assert program.title == "Summer Soccer Camp"
    end

    test "raises on missing required keys" do
      attrs = %{title: "Test"}

      assert_raise ArgumentError, fn ->
        Program.new!(attrs)
      end
    end
  end

  describe "valid?/1" do
    test "returns true for a program with all required fields valid" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440000",
        title: "Summer Soccer Camp",
        description: "Fun soccer activities for kids",
        category: "sports",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("150.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      assert Program.valid?(program)
    end

    test "returns true for a free program (price = 0)" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440002",
        title: "Community Sports Day",
        description: "Free sports activities for all",
        category: "education",
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
        category: "education",
        schedule: "Tuesdays 4pm-5pm",
        age_range: "7-9 years",
        price: Decimal.new("120.00"),
        pricing_period: "per month",
        spots_available: 0
      }

      assert Program.valid?(program)
    end

    test "returns false when title is empty string" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440004",
        title: "",
        description: "Valid description",
        category: "education",
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
        category: "education",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      refute Program.valid?(program)
    end

    test "returns false when description is empty string" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440008",
        title: "Valid Title",
        description: "",
        category: "education",
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
        category: "education",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      refute Program.valid?(program)
    end

    test "returns false when price is negative" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440012",
        title: "Valid Title",
        description: "Valid description",
        category: "education",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("-10.00"),
        pricing_period: "per week",
        spots_available: 20
      }

      refute Program.valid?(program)
    end

    test "returns false when spots_available is negative" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440015",
        title: "Valid Title",
        description: "Valid description",
        category: "education",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: -1
      }

      refute Program.valid?(program)
    end
  end

  describe "sold_out?/1" do
    test "returns true when spots_available is 0" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440018",
        title: "Sold Out Program",
        description: "This program is sold out",
        category: "education",
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
        category: "education",
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
        category: "education",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 100
      }

      refute Program.sold_out?(program)
    end
  end

  describe "free?/1" do
    test "returns true when price is 0" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440021",
        title: "Free Program",
        description: "This program is free",
        category: "education",
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
        category: "education",
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
        category: "education",
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
        category: "education",
        schedule: "Mon-Fri 9am-12pm",
        age_range: "6-10 years",
        price: Decimal.new("150.00"),
        pricing_period: "per week",
        spots_available: 15
      }

      refute Program.free?(program)
    end
  end
end
