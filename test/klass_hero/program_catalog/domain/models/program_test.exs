defmodule KlassHero.ProgramCatalog.Domain.Models.ProgramTest do
  @moduledoc """
  Tests for the Program domain model.

  Note: Full field validation (length limits, category whitelist, etc.) is handled
  by the Ecto schema layer. The domain model provides simplified runtime invariant
  checks via valid?/1 and business logic helpers like sold_out?/1 and free?/1.
  """

  use ExUnit.Case, async: true

  alias KlassHero.ProgramCatalog.Domain.Models.{Instructor, Program}

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

  describe "new/1 with relaxed enforce_keys" do
    @minimal_attrs %{
      id: "550e8400-e29b-41d4-a716-446655440000",
      provider_id: "660e8400-e29b-41d4-a716-446655440001",
      title: "Art Adventures",
      description: "Creative art program for kids",
      category: "arts",
      price: Decimal.new("50.00")
    }

    test "creates program with only required fields" do
      assert {:ok, program} = Program.new(@minimal_attrs)
      assert program.title == "Art Adventures"
      assert program.schedule == nil
      assert program.age_range == nil
      assert program.spots_available == 0
    end

    test "creates program with location" do
      attrs = Map.put(@minimal_attrs, :location, "Community Center, Main St")
      assert {:ok, program} = Program.new(attrs)
      assert program.location == "Community Center, Main St"
    end

    test "creates program with cover_image_url" do
      attrs = Map.put(@minimal_attrs, :cover_image_url, "https://example.com/cover.jpg")
      assert {:ok, program} = Program.new(attrs)
      assert program.cover_image_url == "https://example.com/cover.jpg"
    end

    test "creates program with instructor" do
      {:ok, instructor} = Instructor.new(%{id: "abc", name: "Mike J", headshot_url: nil})
      attrs = Map.put(@minimal_attrs, :instructor, instructor)
      assert {:ok, program} = Program.new(attrs)
      assert program.instructor.name == "Mike J"
    end
  end

  describe "create/1" do
    test "creates program from valid attrs" do
      attrs = %{
        title: "Summer Soccer Camp",
        description: "Fun soccer activities for kids",
        category: "sports",
        price: Decimal.new("150.00"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001",
        spots_available: 20
      }

      assert {:ok, program} = Program.create(attrs)
      assert program.title == "Summer Soccer Camp"
      assert program.category == "sports"
      assert program.id == nil
      assert program.spots_available == 20
    end

    test "creates program with optional fields" do
      attrs = %{
        title: "Art Adventures",
        description: "Creative art program",
        category: "arts",
        price: Decimal.new("50.00"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001",
        schedule: "Mon-Fri 3-5pm",
        age_range: "6-10 years",
        pricing_period: "per week",
        location: "Community Center"
      }

      assert {:ok, program} = Program.create(attrs)
      assert program.schedule == "Mon-Fri 3-5pm"
      assert program.location == "Community Center"
    end

    test "creates program with valid instructor data" do
      attrs = %{
        title: "Coached Program",
        description: "Has instructor",
        category: "sports",
        price: Decimal.new("100.00"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001",
        instructor: %{
          id: "abc-123",
          name: "Jane Coach",
          headshot_url: "https://example.com/photo.jpg"
        }
      }

      assert {:ok, program} = Program.create(attrs)
      assert %Instructor{} = program.instructor
      assert program.instructor.name == "Jane Coach"
    end

    test "creates program without instructor" do
      attrs = %{
        title: "No Coach",
        description: "Self-directed program",
        category: "arts",
        price: Decimal.new("50.00"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001"
      }

      assert {:ok, program} = Program.create(attrs)
      assert program.instructor == nil
    end

    test "defaults spots_available to 0" do
      attrs = %{
        title: "Default Spots",
        description: "No spots specified",
        category: "arts",
        price: Decimal.new("50.00"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001"
      }

      assert {:ok, program} = Program.create(attrs)
      assert program.spots_available == 0
    end

    test "rejects empty title" do
      attrs = %{
        title: "",
        description: "Valid description",
        category: "sports",
        price: Decimal.new("100.00"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001"
      }

      assert {:error, errors} = Program.create(attrs)
      assert is_list(errors)
      assert Enum.any?(errors, &String.contains?(&1, "title"))
    end

    test "rejects whitespace-only title" do
      attrs = %{
        title: "   ",
        description: "Valid",
        category: "sports",
        price: Decimal.new("100.00"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001"
      }

      assert {:error, errors} = Program.create(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "title"))
    end

    test "rejects missing title" do
      attrs = %{
        description: "Valid",
        category: "sports",
        price: Decimal.new("100.00"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001"
      }

      assert {:error, errors} = Program.create(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "title"))
    end

    test "rejects empty description" do
      attrs = %{
        title: "Valid Title",
        description: "",
        category: "sports",
        price: Decimal.new("100.00"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001"
      }

      assert {:error, errors} = Program.create(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "description"))
    end

    test "rejects invalid category" do
      attrs = %{
        title: "Valid Title",
        description: "Valid description",
        category: "invalid_category",
        price: Decimal.new("100.00"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001"
      }

      assert {:error, errors} = Program.create(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "category"))
    end

    test "rejects missing category" do
      attrs = %{
        title: "Valid Title",
        description: "Valid description",
        price: Decimal.new("100.00"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001"
      }

      assert {:error, errors} = Program.create(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "category"))
    end

    test "rejects negative price" do
      attrs = %{
        title: "Valid Title",
        description: "Valid description",
        category: "sports",
        price: Decimal.new("-10.00"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001"
      }

      assert {:error, errors} = Program.create(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "price"))
    end

    test "rejects missing provider_id" do
      attrs = %{
        title: "Valid Title",
        description: "Valid description",
        category: "sports",
        price: Decimal.new("100.00")
      }

      assert {:error, errors} = Program.create(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "rovider"))
    end

    test "rejects negative spots_available" do
      attrs = %{
        title: "Valid",
        description: "Valid",
        category: "sports",
        price: Decimal.new("100.00"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001",
        spots_available: -1
      }

      assert {:error, errors} = Program.create(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "spots"))
    end

    test "rejects invalid instructor data" do
      attrs = %{
        title: "Valid",
        description: "Valid",
        category: "sports",
        price: Decimal.new("100.00"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001",
        instructor: %{id: "", name: "Jane"}
      }

      assert {:error, errors} = Program.create(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "nstructor"))
    end

    test "accepts price of zero (free programs)" do
      attrs = %{
        title: "Free Event",
        description: "A free community event",
        category: "education",
        price: Decimal.new("0"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001"
      }

      assert {:ok, program} = Program.create(attrs)
      assert Program.free?(program)
    end
  end

  describe "apply_changes/2" do
    defp existing_program do
      %Program{
        id: "550e8400-e29b-41d4-a716-446655440000",
        title: "Original Title",
        description: "Original description",
        category: "sports",
        price: Decimal.new("150.00"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001",
        spots_available: 20,
        lock_version: 1
      }
    end

    test "updates title" do
      program = existing_program()
      assert {:ok, updated} = Program.apply_changes(program, %{title: "New Title"})
      assert updated.title == "New Title"
      assert updated.description == "Original description"
    end

    test "updates multiple fields" do
      program = existing_program()

      assert {:ok, updated} =
               Program.apply_changes(program, %{
                 title: "Updated",
                 price: Decimal.new("200.00"),
                 spots_available: 15
               })

      assert updated.title == "Updated"
      assert updated.price == Decimal.new("200.00")
      assert updated.spots_available == 15
    end

    test "preserves fields not in changes" do
      program = existing_program()
      assert {:ok, updated} = Program.apply_changes(program, %{title: "New"})
      assert updated.category == "sports"
      assert updated.provider_id == "660e8400-e29b-41d4-a716-446655440001"
      assert updated.lock_version == 1
    end

    test "adds instructor to program without one" do
      program = existing_program()

      assert {:ok, updated} =
               Program.apply_changes(program, %{
                 instructor: %{id: "abc-123", name: "Jane Coach"}
               })

      assert %Instructor{} = updated.instructor
      assert updated.instructor.name == "Jane Coach"
    end

    test "removes instructor when set to nil" do
      {:ok, instructor} = Instructor.new(%{id: "abc-123", name: "Jane"})
      program = %{existing_program() | instructor: instructor}

      assert {:ok, updated} = Program.apply_changes(program, %{instructor: nil})
      assert updated.instructor == nil
    end

    test "rejects invalid changes (empty title)" do
      program = existing_program()
      assert {:error, errors} = Program.apply_changes(program, %{title: ""})
      assert Enum.any?(errors, &String.contains?(&1, "title"))
    end

    test "rejects invalid changes (negative price)" do
      program = existing_program()
      assert {:error, errors} = Program.apply_changes(program, %{price: Decimal.new("-5.00")})
      assert Enum.any?(errors, &String.contains?(&1, "price"))
    end

    test "rejects invalid category change" do
      program = existing_program()
      assert {:error, errors} = Program.apply_changes(program, %{category: "invalid"})
      assert Enum.any?(errors, &String.contains?(&1, "category"))
    end

    test "ignores provider_id in changes (immutable field)" do
      program = existing_program()
      original_provider_id = program.provider_id

      assert {:ok, updated} =
               Program.apply_changes(program, %{
                 provider_id: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
                 title: "Updated Title"
               })

      assert updated.provider_id == original_provider_id
      assert updated.title == "Updated Title"
    end
  end

  describe "valid?/1 with relaxed fields" do
    test "valid with minimal fields" do
      {:ok, program} =
        Program.new(%{
          id: "550e8400-e29b-41d4-a716-446655440000",
          provider_id: "660e8400-e29b-41d4-a716-446655440001",
          title: "Art Adventures",
          description: "Creative art program for kids",
          category: "arts",
          price: Decimal.new("50.00")
        })

      assert Program.valid?(program)
    end

    test "invalid with empty title" do
      {:ok, program} =
        Program.new(%{
          id: "550e8400-e29b-41d4-a716-446655440000",
          provider_id: "660e8400-e29b-41d4-a716-446655440001",
          title: "Art Adventures",
          description: "Creative art program for kids",
          category: "arts",
          price: Decimal.new("50.00")
        })

      program = %{program | title: ""}
      refute Program.valid?(program)
    end
  end
end
