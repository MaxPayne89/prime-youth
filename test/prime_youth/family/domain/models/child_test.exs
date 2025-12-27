defmodule PrimeYouth.Family.Domain.Models.ChildTest do
  @moduledoc """
  Tests for the Child domain model.

  Verifies domain entity creation, validation, and helper functions.
  """

  use ExUnit.Case, async: true

  alias PrimeYouth.Family.Domain.Models.Child

  # =============================================================================
  # new/1 with valid attributes
  # =============================================================================

  describe "new/1 with valid attributes" do
    test "creates child with all fields" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15],
        notes: "Loves soccer",
        inserted_at: ~U[2025-01-01 12:00:00Z],
        updated_at: ~U[2025-01-01 12:00:00Z]
      }

      child = Child.new(attrs)

      assert %Child{} = child
      assert child.id == "550e8400-e29b-41d4-a716-446655440000"
      assert child.parent_id == "660e8400-e29b-41d4-a716-446655440000"
      assert child.first_name == "Alice"
      assert child.last_name == "Smith"
      assert child.date_of_birth == ~D[2018-06-15]
      assert child.notes == "Loves soccer"
      assert child.inserted_at == ~U[2025-01-01 12:00:00Z]
      assert child.updated_at == ~U[2025-01-01 12:00:00Z]
    end

    test "creates child with minimal required fields" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15]
      }

      child = Child.new(attrs)

      assert %Child{} = child
      assert child.id == "550e8400-e29b-41d4-a716-446655440000"
      assert child.parent_id == "660e8400-e29b-41d4-a716-446655440000"
      assert child.first_name == "Alice"
      assert child.last_name == "Smith"
      assert child.date_of_birth == ~D[2018-06-15]
      assert is_nil(child.notes)
      assert is_nil(child.inserted_at)
      assert is_nil(child.updated_at)
    end

    test "accepts nil for optional notes field" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15],
        notes: nil
      }

      child = Child.new(attrs)

      assert %Child{} = child
      assert is_nil(child.notes)
    end

    test "accepts past date for date_of_birth" do
      yesterday = Date.add(Date.utc_today(), -1)

      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: yesterday
      }

      child = Child.new(attrs)

      assert %Child{} = child
      assert child.date_of_birth == yesterday
    end
  end

  # =============================================================================
  # new/1 first_name validation
  # =============================================================================

  describe "new/1 first_name validation" do
    test "raises ArgumentError when first_name is missing" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        last_name: "Smith",
        date_of_birth: ~D[2018-01-01]
      }

      assert_raise ArgumentError, fn ->
        Child.new(attrs)
      end
    end

    test "accepts single character first_name" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "A",
        last_name: "Smith",
        date_of_birth: ~D[2018-01-01]
      }

      child = Child.new(attrs)

      assert child.first_name == "A"
    end

    test "accepts 100-character first_name (boundary)" do
      long_name = String.duplicate("a", 100)

      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: long_name,
        last_name: "Smith",
        date_of_birth: ~D[2018-01-01]
      }

      child = Child.new(attrs)

      assert child.first_name == long_name
      assert String.length(child.first_name) == 100
    end

    test "accepts multi-word first_name with spaces" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Mary Jane",
        last_name: "Smith",
        date_of_birth: ~D[2018-01-01]
      }

      child = Child.new(attrs)

      assert child.first_name == "Mary Jane"
    end

    test "accepts first_name with special characters" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Jean-Luc",
        last_name: "Smith",
        date_of_birth: ~D[2018-01-01]
      }

      child = Child.new(attrs)

      assert child.first_name == "Jean-Luc"
    end
  end

  # =============================================================================
  # new/1 last_name validation
  # =============================================================================

  describe "new/1 last_name validation" do
    test "raises ArgumentError when last_name is missing" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        date_of_birth: ~D[2018-01-01]
      }

      assert_raise ArgumentError, fn ->
        Child.new(attrs)
      end
    end

    test "accepts single character last_name" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "S",
        date_of_birth: ~D[2018-01-01]
      }

      child = Child.new(attrs)

      assert child.last_name == "S"
    end

    test "accepts 100-character last_name (boundary)" do
      long_name = String.duplicate("b", 100)

      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: long_name,
        date_of_birth: ~D[2018-01-01]
      }

      child = Child.new(attrs)

      assert child.last_name == long_name
      assert String.length(child.last_name) == 100
    end

    test "accepts multi-word last_name with spaces" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Van Der Berg",
        date_of_birth: ~D[2018-01-01]
      }

      child = Child.new(attrs)

      assert child.last_name == "Van Der Berg"
    end

    test "accepts last_name with special characters" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "O'Brien",
        date_of_birth: ~D[2018-01-01]
      }

      child = Child.new(attrs)

      assert child.last_name == "O'Brien"
    end
  end

  # =============================================================================
  # new/1 date_of_birth validation
  # =============================================================================

  describe "new/1 date_of_birth validation" do
    test "raises ArgumentError when date_of_birth is missing" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Smith"
      }

      assert_raise ArgumentError, fn ->
        Child.new(attrs)
      end
    end

    test "accepts yesterday's date (valid past date)" do
      yesterday = Date.add(Date.utc_today(), -1)

      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: yesterday
      }

      child = Child.new(attrs)

      assert child.date_of_birth == yesterday
    end

    test "accepts date from years ago" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2015-03-20]
      }

      child = Child.new(attrs)

      assert child.date_of_birth == ~D[2015-03-20]
    end
  end

  # =============================================================================
  # new/1 parent_id validation
  # =============================================================================

  describe "new/1 parent_id validation" do
    test "raises ArgumentError when parent_id is missing" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-01-01]
      }

      assert_raise ArgumentError, fn ->
        Child.new(attrs)
      end
    end

    test "accepts valid UUID string for parent_id" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-01-01]
      }

      child = Child.new(attrs)

      assert child.parent_id == "660e8400-e29b-41d4-a716-446655440000"
    end
  end

  # =============================================================================
  # new/1 multiple validation errors
  # =============================================================================

  describe "new/1 multiple validation errors" do
    test "raises ArgumentError when multiple required fields are missing" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000"
      }

      assert_raise ArgumentError, fn ->
        Child.new(attrs)
      end
    end

    test "error message includes all missing fields" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000"
      }

      error =
        assert_raise ArgumentError, fn ->
          Child.new(attrs)
        end

      error_message = Exception.message(error)
      assert error_message =~ "parent_id"
      assert error_message =~ "first_name"
      assert error_message =~ "last_name"
      assert error_message =~ "date_of_birth"
    end
  end

  # =============================================================================
  # full_name/1
  # =============================================================================

  describe "full_name/1" do
    test "returns 'FirstName LastName' format" do
      child = %Child{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15]
      }

      assert Child.full_name(child) == "Alice Smith"
    end

    test "handles single-word names" do
      child = %Child{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "A",
        last_name: "B",
        date_of_birth: ~D[2018-06-15]
      }

      assert Child.full_name(child) == "A B"
    end

    test "handles multi-word first and last names" do
      child = %Child{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Mary Jane",
        last_name: "Van Der Berg",
        date_of_birth: ~D[2018-06-15]
      }

      assert Child.full_name(child) == "Mary Jane Van Der Berg"
    end

    test "handles special characters in names" do
      child = %Child{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Jean-Luc",
        last_name: "O'Brien",
        date_of_birth: ~D[2018-06-15]
      }

      assert Child.full_name(child) == "Jean-Luc O'Brien"
    end

    test "preserves exact spacing between names" do
      child = %Child{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15]
      }

      full_name = Child.full_name(child)
      assert full_name == "Alice Smith"
      assert String.contains?(full_name, " ")
      refute String.contains?(full_name, "  ")
    end
  end

  # =============================================================================
  # valid?/1
  # =============================================================================

  describe "valid?/1" do
    test "returns true for valid child with all fields" do
      child = %Child{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15],
        notes: "Loves soccer",
        inserted_at: ~U[2025-01-01 12:00:00Z],
        updated_at: ~U[2025-01-01 12:00:00Z]
      }

      assert Child.valid?(child)
    end

    test "returns true for valid child with minimal fields" do
      child = %Child{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15]
      }

      assert Child.valid?(child)
    end

    test "returns false when id is nil" do
      child = %Child{
        id: nil,
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15]
      }

      refute Child.valid?(child)
    end

    test "returns false when parent_id is nil" do
      child = %Child{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: nil,
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15]
      }

      refute Child.valid?(child)
    end

    test "returns false when first_name is nil" do
      child = %Child{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: nil,
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15]
      }

      refute Child.valid?(child)
    end

    test "returns false when first_name is empty string" do
      child = %Child{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15]
      }

      refute Child.valid?(child)
    end

    test "returns false when last_name is nil" do
      child = %Child{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: nil,
        date_of_birth: ~D[2018-06-15]
      }

      refute Child.valid?(child)
    end

    test "returns false when last_name is empty string" do
      child = %Child{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "",
        date_of_birth: ~D[2018-06-15]
      }

      refute Child.valid?(child)
    end

    test "returns false when date_of_birth is nil" do
      child = %Child{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: nil
      }

      refute Child.valid?(child)
    end

    test "returns false when date_of_birth is not a Date struct" do
      child = %Child{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: "2018-06-15"
      }

      refute Child.valid?(child)
    end

    test "returns true when notes is nil (optional)" do
      child = %Child{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15],
        notes: nil
      }

      assert Child.valid?(child)
    end

    test "returns true for child with all valid field types" do
      child = %Child{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440000",
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15],
        notes: "Loves soccer",
        inserted_at: ~U[2025-01-01 12:00:00Z],
        updated_at: ~U[2025-01-01 12:00:00Z]
      }

      assert Child.valid?(child)
      assert is_binary(child.id)
      assert is_binary(child.parent_id)
      assert is_binary(child.first_name)
      assert is_binary(child.last_name)
      assert match?(%Date{}, child.date_of_birth)
      assert is_binary(child.notes)
      assert match?(%DateTime{}, child.inserted_at)
      assert match?(%DateTime{}, child.updated_at)
    end
  end
end
