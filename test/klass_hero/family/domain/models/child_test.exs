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
