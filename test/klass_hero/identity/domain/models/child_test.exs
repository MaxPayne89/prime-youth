defmodule KlassHero.Identity.Domain.Models.ChildTest do
  @moduledoc """
  Tests for the Child domain entity.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Identity.Domain.Models.Child

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
