defmodule PrimeYouth.Parenting.Adapters.Driven.Persistence.Schemas.ParentSchemaTest do
  @moduledoc """
  Tests for the ParentSchema Ecto schema.

  Tests changeset validations and database constraints.
  """

  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.Parenting.Adapters.Driven.Persistence.Schemas.ParentSchema

  # =============================================================================
  # changeset/2 - Valid Changesets
  # =============================================================================

  describe "changeset/2 with valid attributes" do
    test "creates valid changeset with all fields" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        display_name: "John Doe",
        phone: "+1234567890",
        location: "New York, NY",
        notification_preferences: %{email: true, sms: false}
      }

      changeset = ParentSchema.changeset(%ParentSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :identity_id) == attrs.identity_id
      assert get_change(changeset, :display_name) == "John Doe"
      assert get_change(changeset, :phone) == "+1234567890"
      assert get_change(changeset, :location) == "New York, NY"
      assert get_change(changeset, :notification_preferences) == %{email: true, sms: false}
    end

    test "creates valid changeset with only required fields" do
      attrs = %{identity_id: Ecto.UUID.generate()}

      changeset = ParentSchema.changeset(%ParentSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :identity_id) == attrs.identity_id
      assert is_nil(get_change(changeset, :display_name))
      assert is_nil(get_change(changeset, :phone))
      assert is_nil(get_change(changeset, :location))
      assert is_nil(get_change(changeset, :notification_preferences))
    end

    test "creates valid changeset with display_name at boundary (100 chars)" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        display_name: String.duplicate("a", 100)
      }

      changeset = ParentSchema.changeset(%ParentSchema{}, attrs)

      assert changeset.valid?
    end

    test "creates valid changeset with phone at boundary (20 chars)" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        phone: String.duplicate("1", 20)
      }

      changeset = ParentSchema.changeset(%ParentSchema{}, attrs)

      assert changeset.valid?
    end

    test "creates valid changeset with location at boundary (200 chars)" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        location: String.duplicate("a", 200)
      }

      changeset = ParentSchema.changeset(%ParentSchema{}, attrs)

      assert changeset.valid?
    end
  end

  # =============================================================================
  # changeset/2 - identity_id Validation
  # =============================================================================

  describe "changeset/2 identity_id validation" do
    test "returns invalid changeset when identity_id is missing" do
      attrs = %{display_name: "John Doe"}

      changeset = ParentSchema.changeset(%ParentSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).identity_id
    end

    test "returns invalid changeset when identity_id is nil" do
      attrs = %{identity_id: nil}

      changeset = ParentSchema.changeset(%ParentSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).identity_id
    end
  end

  # =============================================================================
  # changeset/2 - display_name Validation
  # =============================================================================

  describe "changeset/2 display_name validation" do
    test "returns invalid changeset when display_name exceeds 100 characters" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        display_name: String.duplicate("a", 101)
      }

      changeset = ParentSchema.changeset(%ParentSchema{}, attrs)

      refute changeset.valid?
      assert "should be at most 100 character(s)" in errors_on(changeset).display_name
    end

    test "accepts nil display_name" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        display_name: nil
      }

      changeset = ParentSchema.changeset(%ParentSchema{}, attrs)

      assert changeset.valid?
    end
  end

  # =============================================================================
  # changeset/2 - phone Validation
  # =============================================================================

  describe "changeset/2 phone validation" do
    test "returns invalid changeset when phone exceeds 20 characters" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        phone: String.duplicate("1", 21)
      }

      changeset = ParentSchema.changeset(%ParentSchema{}, attrs)

      refute changeset.valid?
      assert "should be at most 20 character(s)" in errors_on(changeset).phone
    end

    test "accepts nil phone" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        phone: nil
      }

      changeset = ParentSchema.changeset(%ParentSchema{}, attrs)

      assert changeset.valid?
    end
  end

  # =============================================================================
  # changeset/2 - location Validation
  # =============================================================================

  describe "changeset/2 location validation" do
    test "returns invalid changeset when location exceeds 200 characters" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        location: String.duplicate("a", 201)
      }

      changeset = ParentSchema.changeset(%ParentSchema{}, attrs)

      refute changeset.valid?
      assert "should be at most 200 character(s)" in errors_on(changeset).location
    end

    test "accepts nil location" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        location: nil
      }

      changeset = ParentSchema.changeset(%ParentSchema{}, attrs)

      assert changeset.valid?
    end
  end

  # =============================================================================
  # Unique Constraint on identity_id
  # =============================================================================

  describe "unique constraint on identity_id" do
    test "prevents duplicate identity_id" do
      identity_id = Ecto.UUID.generate()

      first_attrs = %{identity_id: identity_id, display_name: "First Parent"}
      first_changeset = ParentSchema.changeset(%ParentSchema{}, first_attrs)
      {:ok, _first_parent} = Repo.insert(first_changeset)

      second_attrs = %{identity_id: identity_id, display_name: "Second Parent"}
      second_changeset = ParentSchema.changeset(%ParentSchema{}, second_attrs)

      {:error, changeset} = Repo.insert(second_changeset)

      refute changeset.valid?
      assert "Parent profile already exists for this identity" in errors_on(changeset).identity_id
    end

    test "allows different identity_ids" do
      first_attrs = %{identity_id: Ecto.UUID.generate(), display_name: "First Parent"}
      first_changeset = ParentSchema.changeset(%ParentSchema{}, first_attrs)
      {:ok, _first_parent} = Repo.insert(first_changeset)

      second_attrs = %{identity_id: Ecto.UUID.generate(), display_name: "Second Parent"}
      second_changeset = ParentSchema.changeset(%ParentSchema{}, second_attrs)
      {:ok, second_parent} = Repo.insert(second_changeset)

      assert second_parent.display_name == "Second Parent"
    end
  end
end
