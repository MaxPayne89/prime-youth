defmodule PrimeYouth.Parenting.Application.UseCases.CreateParentProfileTest do
  @moduledoc """
  Tests for the CreateParentProfile use case.

  Tests the orchestration of parent profile creation via the repository port.
  """

  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.Parenting.Application.UseCases.CreateParentProfile
  alias PrimeYouth.Parenting.Domain.Models.Parent

  # =============================================================================
  # execute/1 - Successful Creation
  # =============================================================================

  describe "execute/1 successful creation" do
    test "creates parent profile with all fields" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        display_name: "John Doe",
        phone: "+1234567890",
        location: "New York, NY",
        notification_preferences: %{email: true, sms: false}
      }

      assert {:ok, %Parent{} = parent} = CreateParentProfile.execute(attrs)
      assert is_binary(parent.id)
      assert parent.identity_id == attrs.identity_id
      assert parent.display_name == "John Doe"
      assert parent.phone == "+1234567890"
      assert parent.location == "New York, NY"
      assert parent.notification_preferences == %{email: true, sms: false}
      assert %DateTime{} = parent.inserted_at
      assert %DateTime{} = parent.updated_at
    end

    test "creates parent profile with minimal fields (identity_id only)" do
      attrs = %{identity_id: Ecto.UUID.generate()}

      assert {:ok, %Parent{} = parent} = CreateParentProfile.execute(attrs)
      assert is_binary(parent.id)
      assert parent.identity_id == attrs.identity_id
      assert is_nil(parent.display_name)
      assert is_nil(parent.phone)
      assert is_nil(parent.location)
      assert is_nil(parent.notification_preferences)
    end

    test "auto-generates UUID for parent id" do
      attrs = %{identity_id: Ecto.UUID.generate()}

      assert {:ok, %Parent{} = parent} = CreateParentProfile.execute(attrs)
      assert {:ok, _} = Ecto.UUID.cast(parent.id)
    end

    test "generates timestamps on creation" do
      attrs = %{identity_id: Ecto.UUID.generate()}

      assert {:ok, %Parent{} = parent} = CreateParentProfile.execute(attrs)
      assert %DateTime{} = parent.inserted_at
      assert %DateTime{} = parent.updated_at
      assert DateTime.compare(parent.inserted_at, parent.updated_at) in [:eq, :lt]
    end
  end

  # =============================================================================
  # execute/1 - Domain Validation
  # =============================================================================

  describe "execute/1 domain validation" do
    test "returns validation_error when identity_id is empty string" do
      attrs = %{identity_id: ""}

      assert {:error, {:validation_error, errors}} = CreateParentProfile.execute(attrs)
      assert "Identity ID cannot be empty" in errors
    end

    test "returns validation_error when identity_id is whitespace only" do
      attrs = %{identity_id: "   "}

      assert {:error, {:validation_error, errors}} = CreateParentProfile.execute(attrs)
      assert "Identity ID cannot be empty" in errors
    end

    test "returns validation_error when display_name is empty string" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        display_name: ""
      }

      assert {:error, {:validation_error, errors}} = CreateParentProfile.execute(attrs)
      assert "Display name cannot be empty if provided" in errors
    end

    test "returns validation_error when display_name exceeds 100 characters" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        display_name: String.duplicate("a", 101)
      }

      assert {:error, {:validation_error, errors}} = CreateParentProfile.execute(attrs)
      assert "Display name must be 100 characters or less" in errors
    end

    test "returns validation_error when phone is empty string" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        phone: ""
      }

      assert {:error, {:validation_error, errors}} = CreateParentProfile.execute(attrs)
      assert "Phone cannot be empty if provided" in errors
    end

    test "returns validation_error when phone exceeds 20 characters" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        phone: String.duplicate("1", 21)
      }

      assert {:error, {:validation_error, errors}} = CreateParentProfile.execute(attrs)
      assert "Phone must be 20 characters or less" in errors
    end

    test "returns validation_error when location is empty string" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        location: ""
      }

      assert {:error, {:validation_error, errors}} = CreateParentProfile.execute(attrs)
      assert "Location cannot be empty if provided" in errors
    end

    test "returns validation_error when location exceeds 200 characters" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        location: String.duplicate("a", 201)
      }

      assert {:error, {:validation_error, errors}} = CreateParentProfile.execute(attrs)
      assert "Location must be 200 characters or less" in errors
    end

    test "returns validation_error when notification_preferences is not a map" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        notification_preferences: "not a map"
      }

      assert {:error, {:validation_error, errors}} = CreateParentProfile.execute(attrs)
      assert "Notification preferences must be a map" in errors
    end

    test "returns multiple validation errors for multiple invalid fields" do
      attrs = %{
        identity_id: "",
        display_name: "",
        phone: String.duplicate("1", 21)
      }

      assert {:error, {:validation_error, errors}} = CreateParentProfile.execute(attrs)
      assert "Identity ID cannot be empty" in errors
      assert "Display name cannot be empty if provided" in errors
      assert "Phone must be 20 characters or less" in errors
      assert length(errors) == 3
    end
  end

  # =============================================================================
  # execute/1 - Error Cases
  # =============================================================================

  describe "execute/1 error cases" do
    test "returns :duplicate_identity when profile already exists for identity_id" do
      identity_id = Ecto.UUID.generate()
      first_attrs = %{identity_id: identity_id, display_name: "First Parent"}
      second_attrs = %{identity_id: identity_id, display_name: "Second Parent"}

      assert {:ok, _first_parent} = CreateParentProfile.execute(first_attrs)
      assert {:error, :duplicate_identity} = CreateParentProfile.execute(second_attrs)
    end

    test "allows creating profiles with different identity_ids" do
      first_attrs = %{identity_id: Ecto.UUID.generate(), display_name: "First Parent"}
      second_attrs = %{identity_id: Ecto.UUID.generate(), display_name: "Second Parent"}

      assert {:ok, first_parent} = CreateParentProfile.execute(first_attrs)
      assert {:ok, second_parent} = CreateParentProfile.execute(second_attrs)

      assert first_parent.id != second_parent.id
      assert first_parent.identity_id != second_parent.identity_id
    end
  end
end
