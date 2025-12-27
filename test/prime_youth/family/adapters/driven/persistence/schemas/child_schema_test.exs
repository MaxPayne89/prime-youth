defmodule PrimeYouth.Family.Adapters.Driven.Persistence.Schemas.ChildSchemaTest do
  @moduledoc """
  Tests for the ChildSchema Ecto schema.

  Verifies changeset validation, constraints, and database schema mapping.
  """

  use PrimeYouth.DataCase, async: true

  import Ecto.Changeset

  alias PrimeYouth.Family.Adapters.Driven.Persistence.Schemas.ChildSchema

  # =============================================================================
  # changeset/2 with valid attributes
  # =============================================================================

  describe "changeset/2 with valid attributes" do
    test "creates valid changeset with all fields" do
      attrs = %{
        parent_id: Ecto.UUID.generate(),
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15],
        notes: "Loves soccer"
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :parent_id) == attrs.parent_id
      assert get_change(changeset, :first_name) == "Alice"
      assert get_change(changeset, :last_name) == "Smith"
      assert get_change(changeset, :date_of_birth) == ~D[2018-06-15]
      assert get_change(changeset, :notes) == "Loves soccer"
    end

    test "creates valid changeset with minimal required fields" do
      attrs = %{
        parent_id: Ecto.UUID.generate(),
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15]
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :parent_id) == attrs.parent_id
      assert get_change(changeset, :first_name) == "Alice"
      assert get_change(changeset, :last_name) == "Smith"
      assert get_change(changeset, :date_of_birth) == ~D[2018-06-15]
      refute get_change(changeset, :notes)
    end

    test "accepts 1-character first_name (boundary)" do
      attrs = %{
        parent_id: Ecto.UUID.generate(),
        first_name: "A",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15]
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :first_name) == "A"
    end

    test "accepts 100-character first_name (boundary)" do
      long_name = String.duplicate("a", 100)

      attrs = %{
        parent_id: Ecto.UUID.generate(),
        first_name: long_name,
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15]
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :first_name) == long_name
      assert String.length(get_change(changeset, :first_name)) == 100
    end

    test "accepts yesterday as date_of_birth (boundary)" do
      yesterday = Date.add(Date.utc_today(), -1)

      attrs = %{
        parent_id: Ecto.UUID.generate(),
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: yesterday
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :date_of_birth) == yesterday
    end
  end

  # =============================================================================
  # changeset/2 first_name validation
  # =============================================================================

  describe "changeset/2 first_name validation" do
    test "marks changeset invalid when first_name is missing" do
      attrs = %{
        parent_id: Ecto.UUID.generate(),
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15]
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).first_name
    end

    test "marks changeset invalid when first_name is empty string" do
      attrs = %{
        parent_id: Ecto.UUID.generate(),
        first_name: "",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15]
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).first_name
    end

    test "marks changeset invalid when first_name exceeds 100 characters" do
      long_name = String.duplicate("a", 101)

      attrs = %{
        parent_id: Ecto.UUID.generate(),
        first_name: long_name,
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15]
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      refute changeset.valid?
      assert "should be at most 100 character(s)" in errors_on(changeset).first_name
    end

    test "error message includes length constraint" do
      long_name = String.duplicate("a", 101)

      attrs = %{
        parent_id: Ecto.UUID.generate(),
        first_name: long_name,
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15]
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      refute changeset.valid?
      errors = errors_on(changeset).first_name
      assert "should be at most 100 character(s)" in errors
    end
  end

  # =============================================================================
  # changeset/2 last_name validation
  # =============================================================================

  describe "changeset/2 last_name validation" do
    test "marks changeset invalid when last_name is missing" do
      attrs = %{
        parent_id: Ecto.UUID.generate(),
        first_name: "Alice",
        date_of_birth: ~D[2018-06-15]
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).last_name
    end

    test "marks changeset invalid when last_name is empty string" do
      attrs = %{
        parent_id: Ecto.UUID.generate(),
        first_name: "Alice",
        last_name: "",
        date_of_birth: ~D[2018-06-15]
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).last_name
    end

    test "marks changeset invalid when last_name exceeds 100 characters" do
      long_name = String.duplicate("b", 101)

      attrs = %{
        parent_id: Ecto.UUID.generate(),
        first_name: "Alice",
        last_name: long_name,
        date_of_birth: ~D[2018-06-15]
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      refute changeset.valid?
      assert "should be at most 100 character(s)" in errors_on(changeset).last_name
    end

    test "error message includes length constraint" do
      long_name = String.duplicate("b", 101)

      attrs = %{
        parent_id: Ecto.UUID.generate(),
        first_name: "Alice",
        last_name: long_name,
        date_of_birth: ~D[2018-06-15]
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      refute changeset.valid?
      errors = errors_on(changeset).last_name
      assert "should be at most 100 character(s)" in errors
    end
  end

  # =============================================================================
  # changeset/2 date_of_birth validation
  # =============================================================================

  describe "changeset/2 date_of_birth validation" do
    test "marks changeset invalid when date_of_birth is missing" do
      attrs = %{
        parent_id: Ecto.UUID.generate(),
        first_name: "Alice",
        last_name: "Smith"
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).date_of_birth
    end

    test "marks changeset invalid when date_of_birth is today" do
      today = Date.utc_today()

      attrs = %{
        parent_id: Ecto.UUID.generate(),
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: today
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      refute changeset.valid?
      assert "must be in the past" in errors_on(changeset).date_of_birth
    end

    test "marks changeset invalid when date_of_birth is in the future" do
      future_date = Date.add(Date.utc_today(), 1)

      attrs = %{
        parent_id: Ecto.UUID.generate(),
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: future_date
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      refute changeset.valid?
      assert "must be in the past" in errors_on(changeset).date_of_birth
    end

    test "error message indicates past date requirement" do
      future_date = Date.add(Date.utc_today(), 365)

      attrs = %{
        parent_id: Ecto.UUID.generate(),
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: future_date
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      refute changeset.valid?
      errors = errors_on(changeset).date_of_birth
      assert "must be in the past" in errors
    end
  end

  # =============================================================================
  # changeset/2 parent_id validation
  # =============================================================================

  describe "changeset/2 parent_id validation" do
    test "marks changeset invalid when parent_id is missing" do
      attrs = %{
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15]
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).parent_id
    end

    test "accepts valid binary UUID for parent_id" do
      parent_id = Ecto.UUID.generate()

      attrs = %{
        parent_id: parent_id,
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15]
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :parent_id) == parent_id
    end

    test "foreign key constraint is defined on parent_id" do
      attrs = %{
        parent_id: Ecto.UUID.generate(),
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15]
      }

      changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

      assert changeset.valid?

      constraint =
        Enum.find(changeset.constraints, fn c ->
          c.field == :parent_id && c.type == :foreign_key
        end)

      assert constraint != nil
      assert constraint.field == :parent_id
      assert constraint.type == :foreign_key
    end
  end
end
