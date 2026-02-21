defmodule KlassHero.Family.Domain.Models.ChildTest do
  @moduledoc """
  Tests for the Child domain entity.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Family.Domain.Models.Child

  describe "new/1 with valid attributes" do
    test "creates child with all fields" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440001",
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15],
        emergency_contact: "555-1234",
        support_needs: "Extra help with reading",
        allergies: "Peanuts"
      }

      assert {:ok, child} = Child.new(attrs)
      assert child.id == attrs.id
      assert child.parent_id == attrs.parent_id
      assert child.first_name == "Emma"
      assert child.last_name == "Smith"
      assert child.date_of_birth == ~D[2015-06-15]
      assert child.emergency_contact == "555-1234"
      assert child.support_needs == "Extra help with reading"
      assert child.allergies == "Peanuts"
    end

    test "creates child with only required fields" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440001",
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15]
      }

      assert {:ok, child} = Child.new(attrs)
      assert is_nil(child.emergency_contact)
      assert is_nil(child.support_needs)
      assert is_nil(child.allergies)
    end
  end

  describe "new/1 validation errors" do
    test "returns error when parent_id is empty" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "",
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15]
      }

      assert {:error, errors} = Child.new(attrs)
      assert "Parent ID cannot be empty" in errors
    end

    test "returns error when first_name is empty" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "uuid-123",
        first_name: "",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15]
      }

      assert {:error, errors} = Child.new(attrs)
      assert "First name cannot be empty" in errors
    end

    test "returns error when last_name is empty" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "uuid-123",
        first_name: "Emma",
        last_name: "",
        date_of_birth: ~D[2015-06-15]
      }

      assert {:error, errors} = Child.new(attrs)
      assert "Last name cannot be empty" in errors
    end

    test "returns error when date_of_birth is in the future" do
      future_date = Date.add(Date.utc_today(), 1)

      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "uuid-123",
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: future_date
      }

      assert {:error, errors} = Child.new(attrs)
      assert "Date of birth cannot be in the future" in errors
    end
  end

  describe "from_persistence/1" do
    test "reconstructs child from valid persistence data" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440001",
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15],
        emergency_contact: "555-1234",
        support_needs: nil,
        allergies: nil,
        inserted_at: ~U[2025-01-01 12:00:00Z],
        updated_at: ~U[2025-01-01 12:00:00Z]
      }

      assert {:ok, child} = Child.from_persistence(attrs)
      assert child.id == attrs.id
      assert child.first_name == "Emma"
      assert child.emergency_contact == "555-1234"
    end

    test "returns error when required key is missing" do
      # Missing :date_of_birth which is in @enforce_keys
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440001",
        first_name: "Emma",
        last_name: "Smith"
      }

      assert {:error, :invalid_persistence_data} = Child.from_persistence(attrs)
    end
  end

  describe "full_name/1" do
    test "returns combined first and last name" do
      {:ok, child} =
        Child.new(%{
          id: "550e8400-e29b-41d4-a716-446655440000",
          parent_id: "uuid-123",
          first_name: "Emma",
          last_name: "Smith",
          date_of_birth: ~D[2015-06-15]
        })

      assert Child.full_name(child) == "Emma Smith"
    end
  end

  describe "anonymized_attrs/0" do
    test "includes date_of_birth as nil" do
      attrs = Child.anonymized_attrs()

      assert Map.has_key?(attrs, :date_of_birth)
      assert attrs.date_of_birth == nil
    end

    test "includes all PII fields" do
      attrs = Child.anonymized_attrs()

      assert attrs.first_name == "Anonymized"
      assert attrs.last_name == "Child"
      assert attrs.date_of_birth == nil
      assert attrs.emergency_contact == nil
      assert attrs.support_needs == nil
      assert attrs.allergies == nil
    end
  end

  describe "new/1 gender validation" do
    setup do
      %{
        base_attrs: %{
          id: "550e8400-e29b-41d4-a716-446655440000",
          parent_id: "660e8400-e29b-41d4-a716-446655440001",
          first_name: "Emma",
          last_name: "Smith",
          date_of_birth: ~D[2015-06-15]
        }
      }
    end

    test "accepts all valid gender values", %{base_attrs: base} do
      for gender <- ~w(male female diverse not_specified) do
        assert {:ok, child} = Child.new(Map.put(base, :gender, gender))
        assert child.gender == gender
      end
    end

    test "rejects invalid gender", %{base_attrs: base} do
      assert {:error, errors} = Child.new(Map.put(base, :gender, "other"))
      assert Enum.any?(errors, &String.contains?(&1, "Gender must be one of"))
    end

    test "defaults gender to not_specified when nil", %{base_attrs: base} do
      assert {:ok, child} = Child.new(Map.put(base, :gender, nil))
      assert child.gender == "not_specified"
    end

    test "defaults gender to not_specified when not provided", %{base_attrs: base} do
      assert {:ok, child} = Child.new(base)
      assert child.gender == "not_specified"
    end
  end

  describe "new/1 school_grade validation" do
    setup do
      %{
        base_attrs: %{
          id: "550e8400-e29b-41d4-a716-446655440000",
          parent_id: "660e8400-e29b-41d4-a716-446655440001",
          first_name: "Emma",
          last_name: "Smith",
          date_of_birth: ~D[2015-06-15]
        }
      }
    end

    test "accepts nil school_grade", %{base_attrs: base} do
      assert {:ok, child} = Child.new(base)
      assert is_nil(child.school_grade)
    end

    test "accepts valid school_grade values 1 through 13", %{base_attrs: base} do
      for grade <- 1..13 do
        assert {:ok, child} = Child.new(Map.put(base, :school_grade, grade))
        assert child.school_grade == grade
      end
    end

    test "rejects school_grade of 0", %{base_attrs: base} do
      assert {:error, errors} = Child.new(Map.put(base, :school_grade, 0))
      assert "School grade must be between 1 and 13" in errors
    end

    test "rejects school_grade of 14", %{base_attrs: base} do
      assert {:error, errors} = Child.new(Map.put(base, :school_grade, 14))
      assert "School grade must be between 1 and 13" in errors
    end

    test "rejects non-integer school_grade", %{base_attrs: base} do
      assert {:error, errors} = Child.new(Map.put(base, :school_grade, "5th"))
      assert "School grade must be between 1 and 13" in errors
    end
  end

  describe "school_name" do
    test "accepts school_name in new/1" do
      attrs = %{
        id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate(),
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2017-03-15],
        school_name: "Berlin International School"
      }

      assert {:ok, child} = Child.new(attrs)
      assert child.school_name == "Berlin International School"
    end

    test "defaults school_name to nil" do
      attrs = %{
        id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate(),
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2017-03-15]
      }

      assert {:ok, child} = Child.new(attrs)
      assert is_nil(child.school_name)
    end
  end

  describe "age_in_months/2" do
    test "computes age in months for a basic case" do
      {:ok, child} =
        Child.new(%{
          id: "550e8400-e29b-41d4-a716-446655440000",
          parent_id: "uuid-123",
          first_name: "Emma",
          last_name: "Smith",
          date_of_birth: ~D[2015-06-15]
        })

      # 2 years and 6 months later on the same day
      assert Child.age_in_months(child, ~D[2017-12-15]) == 30
    end

    test "subtracts a month when reference day is before birth day" do
      {:ok, child} =
        Child.new(%{
          id: "550e8400-e29b-41d4-a716-446655440000",
          parent_id: "uuid-123",
          first_name: "Emma",
          last_name: "Smith",
          date_of_birth: ~D[2015-06-20]
        })

      # Reference date is June 10 — hasn't reached the 20th yet
      assert Child.age_in_months(child, ~D[2016-06-10]) == 11
    end

    test "does not subtract when reference day is on or after birth day" do
      {:ok, child} =
        Child.new(%{
          id: "550e8400-e29b-41d4-a716-446655440000",
          parent_id: "uuid-123",
          first_name: "Emma",
          last_name: "Smith",
          date_of_birth: ~D[2015-06-15]
        })

      assert Child.age_in_months(child, ~D[2016-06-15]) == 12
      assert Child.age_in_months(child, ~D[2016-06-20]) == 12
    end

    test "returns 0 when reference date equals date of birth" do
      {:ok, child} =
        Child.new(%{
          id: "550e8400-e29b-41d4-a716-446655440000",
          parent_id: "uuid-123",
          first_name: "Emma",
          last_name: "Smith",
          date_of_birth: ~D[2015-06-15]
        })

      assert Child.age_in_months(child, ~D[2015-06-15]) == 0
    end

    test "returns 0 when reference date is before date of birth" do
      {:ok, child} =
        Child.new(%{
          id: "550e8400-e29b-41d4-a716-446655440000",
          parent_id: "uuid-123",
          first_name: "Emma",
          last_name: "Smith",
          date_of_birth: ~D[2015-06-15]
        })

      assert Child.age_in_months(child, ~D[2015-01-01]) == 0
    end
  end

  describe "valid?/1" do
    test "returns true for valid child" do
      {:ok, child} =
        Child.new(%{
          id: "550e8400-e29b-41d4-a716-446655440000",
          parent_id: "uuid-123",
          first_name: "Emma",
          last_name: "Smith",
          date_of_birth: ~D[2015-06-15]
        })

      assert Child.valid?(child)
    end

    test "returns false for child with empty first_name" do
      child = %Child{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "uuid-123",
        first_name: "",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15]
      }

      refute Child.valid?(child)
    end
  end
end
