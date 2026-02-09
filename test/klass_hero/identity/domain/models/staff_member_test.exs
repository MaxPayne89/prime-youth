defmodule KlassHero.Identity.Domain.Models.StaffMemberTest do
  use ExUnit.Case, async: true

  alias KlassHero.Identity.Domain.Models.StaffMember

  @valid_attrs %{
    id: "550e8400-e29b-41d4-a716-446655440000",
    provider_id: "660e8400-e29b-41d4-a716-446655440001",
    first_name: "Mike",
    last_name: "Johnson"
  }

  describe "new/1 with valid attributes" do
    test "creates staff member with required fields only" do
      assert {:ok, staff} = StaffMember.new(@valid_attrs)
      assert staff.first_name == "Mike"
      assert staff.last_name == "Johnson"
      assert staff.tags == []
      assert staff.qualifications == []
      assert staff.active == true
    end

    test "creates staff member with all fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          role: "Head Coach",
          email: "mike@example.com",
          bio: "10 years coaching experience.",
          headshot_url: "https://example.com/photo.jpg",
          tags: ["sports"],
          qualifications: ["First Aid", "UEFA B License"],
          active: true
        })

      assert {:ok, staff} = StaffMember.new(attrs)
      assert staff.role == "Head Coach"
      assert staff.tags == ["sports"]
      assert staff.qualifications == ["First Aid", "UEFA B License"]
    end
  end

  describe "new/1 validation errors" do
    test "rejects empty first_name" do
      assert {:error, errors} = StaffMember.new(%{@valid_attrs | first_name: ""})
      assert "First name cannot be empty" in errors
    end

    test "rejects empty last_name" do
      assert {:error, errors} = StaffMember.new(%{@valid_attrs | last_name: ""})
      assert "Last name cannot be empty" in errors
    end

    test "rejects empty provider_id" do
      assert {:error, errors} = StaffMember.new(%{@valid_attrs | provider_id: ""})
      assert "Provider ID cannot be empty" in errors
    end

    test "rejects invalid tag" do
      attrs = Map.put(@valid_attrs, :tags, ["sports", "invalid_tag"])
      assert {:error, errors} = StaffMember.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "invalid_tag"))
    end

    test "rejects first_name over 100 characters" do
      long = String.duplicate("a", 101)
      assert {:error, errors} = StaffMember.new(%{@valid_attrs | first_name: long})
      assert "First name must be 100 characters or less" in errors
    end
  end

  describe "full_name/1" do
    test "returns first + last" do
      {:ok, staff} = StaffMember.new(@valid_attrs)
      assert StaffMember.full_name(staff) == "Mike Johnson"
    end
  end

  describe "initials/1" do
    test "returns first letter of each name" do
      {:ok, staff} = StaffMember.new(@valid_attrs)
      assert StaffMember.initials(staff) == "MJ"
    end
  end

  describe "from_persistence/1" do
    test "reconstructs without validation" do
      attrs =
        Map.merge(@valid_attrs, %{
          tags: [],
          qualifications: [],
          active: true,
          inserted_at: ~U[2025-01-01 12:00:00Z],
          updated_at: ~U[2025-01-01 12:00:00Z]
        })

      assert {:ok, staff} = StaffMember.from_persistence(attrs)
      assert staff.first_name == "Mike"
    end

    test "errors on missing enforce key" do
      assert {:error, :invalid_persistence_data} =
               StaffMember.from_persistence(%{id: "abc", first_name: "X"})
    end
  end
end
