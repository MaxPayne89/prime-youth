defmodule PrimeYouth.Parenting.Domain.Models.ParentTest do
  @moduledoc """
  Tests for the Parent domain entity.

  Tests business rules and validation logic for parent profiles.
  """

  use ExUnit.Case, async: true

  alias PrimeYouth.Parenting.Domain.Models.Parent

  # =============================================================================
  # new/1 - Valid Parents
  # =============================================================================

  describe "new/1 with valid attributes" do
    test "creates parent with all fields" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440001",
        display_name: "John Doe",
        phone: "+1234567890",
        location: "New York, NY",
        notification_preferences: %{email: true, sms: false}
      }

      assert {:ok, parent} = Parent.new(attrs)
      assert parent.id == "550e8400-e29b-41d4-a716-446655440000"
      assert parent.identity_id == "660e8400-e29b-41d4-a716-446655440001"
      assert parent.display_name == "John Doe"
      assert parent.phone == "+1234567890"
      assert parent.location == "New York, NY"
      assert parent.notification_preferences == %{email: true, sms: false}
    end

    test "creates parent with only required fields" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440001"
      }

      assert {:ok, parent} = Parent.new(attrs)
      assert parent.id == "550e8400-e29b-41d4-a716-446655440000"
      assert parent.identity_id == "660e8400-e29b-41d4-a716-446655440001"
      assert is_nil(parent.display_name)
      assert is_nil(parent.phone)
      assert is_nil(parent.location)
      assert is_nil(parent.notification_preferences)
    end

    test "creates parent with timestamps" do
      now = DateTime.utc_now()

      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440001",
        inserted_at: now,
        updated_at: now
      }

      assert {:ok, parent} = Parent.new(attrs)
      assert parent.inserted_at == now
      assert parent.updated_at == now
    end

    test "creates parent with empty notification_preferences map" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440001",
        notification_preferences: %{}
      }

      assert {:ok, parent} = Parent.new(attrs)
      assert parent.notification_preferences == %{}
    end
  end

  # =============================================================================
  # new/1 - identity_id Validation
  # =============================================================================

  describe "new/1 identity_id validation" do
    test "returns error when identity_id is empty string" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: ""
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Identity ID cannot be empty" in errors
    end

    test "returns error when identity_id is whitespace only" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "   "
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Identity ID cannot be empty" in errors
    end

    test "returns error when identity_id is not a string" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: 12345
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Identity ID must be a string" in errors
    end

    test "returns error when identity_id is nil" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: nil
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Identity ID must be a string" in errors
    end

    test "accepts identity_id with leading/trailing spaces (trimmed for validation)" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "  uuid-123  "
      }

      assert {:ok, parent} = Parent.new(attrs)
      assert parent.identity_id == "  uuid-123  "
    end
  end

  # =============================================================================
  # new/1 - display_name Validation
  # =============================================================================

  describe "new/1 display_name validation" do
    test "accepts nil display_name" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        display_name: nil
      }

      assert {:ok, parent} = Parent.new(attrs)
      assert is_nil(parent.display_name)
    end

    test "accepts display_name at boundary (100 chars)" do
      display_name = String.duplicate("a", 100)

      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        display_name: display_name
      }

      assert {:ok, parent} = Parent.new(attrs)
      assert String.length(parent.display_name) == 100
    end

    test "accepts display_name with 1 character" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        display_name: "J"
      }

      assert {:ok, parent} = Parent.new(attrs)
      assert parent.display_name == "J"
    end

    test "returns error when display_name is empty string" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        display_name: ""
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Display name cannot be empty if provided" in errors
    end

    test "returns error when display_name is whitespace only" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        display_name: "   "
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Display name cannot be empty if provided" in errors
    end

    test "returns error when display_name exceeds 100 characters" do
      display_name = String.duplicate("a", 101)

      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        display_name: display_name
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Display name must be 100 characters or less" in errors
    end

    test "returns error when display_name is not a string" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        display_name: 12345
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Display name must be a string" in errors
    end
  end

  # =============================================================================
  # new/1 - phone Validation
  # =============================================================================

  describe "new/1 phone validation" do
    test "accepts nil phone" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        phone: nil
      }

      assert {:ok, parent} = Parent.new(attrs)
      assert is_nil(parent.phone)
    end

    test "accepts phone at boundary (20 chars)" do
      phone = String.duplicate("1", 20)

      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        phone: phone
      }

      assert {:ok, parent} = Parent.new(attrs)
      assert String.length(parent.phone) == 20
    end

    test "accepts phone with 1 character" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        phone: "1"
      }

      assert {:ok, parent} = Parent.new(attrs)
      assert parent.phone == "1"
    end

    test "returns error when phone is empty string" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        phone: ""
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Phone cannot be empty if provided" in errors
    end

    test "returns error when phone is whitespace only" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        phone: "   "
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Phone cannot be empty if provided" in errors
    end

    test "returns error when phone exceeds 20 characters" do
      phone = String.duplicate("1", 21)

      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        phone: phone
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Phone must be 20 characters or less" in errors
    end

    test "returns error when phone is not a string" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        phone: 1_234_567_890
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Phone must be a string" in errors
    end
  end

  # =============================================================================
  # new/1 - location Validation
  # =============================================================================

  describe "new/1 location validation" do
    test "accepts nil location" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        location: nil
      }

      assert {:ok, parent} = Parent.new(attrs)
      assert is_nil(parent.location)
    end

    test "accepts location at boundary (200 chars)" do
      location = String.duplicate("a", 200)

      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        location: location
      }

      assert {:ok, parent} = Parent.new(attrs)
      assert String.length(parent.location) == 200
    end

    test "accepts location with 1 character" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        location: "X"
      }

      assert {:ok, parent} = Parent.new(attrs)
      assert parent.location == "X"
    end

    test "returns error when location is empty string" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        location: ""
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Location cannot be empty if provided" in errors
    end

    test "returns error when location is whitespace only" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        location: "   "
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Location cannot be empty if provided" in errors
    end

    test "returns error when location exceeds 200 characters" do
      location = String.duplicate("a", 201)

      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        location: location
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Location must be 200 characters or less" in errors
    end

    test "returns error when location is not a string" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        location: 12345
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Location must be a string" in errors
    end
  end

  # =============================================================================
  # new/1 - notification_preferences Validation
  # =============================================================================

  describe "new/1 notification_preferences validation" do
    test "accepts nil notification_preferences" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        notification_preferences: nil
      }

      assert {:ok, parent} = Parent.new(attrs)
      assert is_nil(parent.notification_preferences)
    end

    test "accepts empty map notification_preferences" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        notification_preferences: %{}
      }

      assert {:ok, parent} = Parent.new(attrs)
      assert parent.notification_preferences == %{}
    end

    test "accepts map with various values" do
      prefs = %{
        email: true,
        sms: false,
        push: "enabled",
        frequency: 7
      }

      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        notification_preferences: prefs
      }

      assert {:ok, parent} = Parent.new(attrs)
      assert parent.notification_preferences == prefs
    end

    test "returns error when notification_preferences is not a map" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        notification_preferences: "invalid"
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Notification preferences must be a map" in errors
    end

    test "returns error when notification_preferences is a list" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        notification_preferences: [:email, :sms]
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Notification preferences must be a map" in errors
    end
  end

  # =============================================================================
  # new/1 - Multiple Validation Errors
  # =============================================================================

  describe "new/1 multiple validation errors" do
    test "returns all errors when multiple fields are invalid" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "",
        display_name: String.duplicate("a", 101),
        phone: String.duplicate("1", 21),
        location: "",
        notification_preferences: "invalid"
      }

      assert {:error, errors} = Parent.new(attrs)
      assert "Identity ID cannot be empty" in errors
      assert "Display name must be 100 characters or less" in errors
      assert "Phone must be 20 characters or less" in errors
      assert "Location cannot be empty if provided" in errors
      assert "Notification preferences must be a map" in errors
    end
  end

  # =============================================================================
  # valid?/1
  # =============================================================================

  describe "valid?/1" do
    test "returns true for valid parent" do
      {:ok, parent} =
        Parent.new(%{
          id: "550e8400-e29b-41d4-a716-446655440000",
          identity_id: "uuid-123",
          display_name: "John Doe"
        })

      assert Parent.valid?(parent)
    end

    test "returns false for parent with empty identity_id" do
      parent = %Parent{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: ""
      }

      refute Parent.valid?(parent)
    end

    test "returns false for parent with invalid display_name" do
      parent = %Parent{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        display_name: String.duplicate("a", 101)
      }

      refute Parent.valid?(parent)
    end
  end

  # =============================================================================
  # has_notification_preferences?/1
  # =============================================================================

  describe "has_notification_preferences?/1" do
    test "returns false when notification_preferences is nil" do
      {:ok, parent} =
        Parent.new(%{
          id: "550e8400-e29b-41d4-a716-446655440000",
          identity_id: "uuid-123",
          notification_preferences: nil
        })

      refute Parent.has_notification_preferences?(parent)
    end

    test "returns false when notification_preferences is empty map" do
      {:ok, parent} =
        Parent.new(%{
          id: "550e8400-e29b-41d4-a716-446655440000",
          identity_id: "uuid-123",
          notification_preferences: %{}
        })

      refute Parent.has_notification_preferences?(parent)
    end

    test "returns true when notification_preferences has content" do
      {:ok, parent} =
        Parent.new(%{
          id: "550e8400-e29b-41d4-a716-446655440000",
          identity_id: "uuid-123",
          notification_preferences: %{email: true}
        })

      assert Parent.has_notification_preferences?(parent)
    end

    test "returns true when notification_preferences has multiple entries" do
      {:ok, parent} =
        Parent.new(%{
          id: "550e8400-e29b-41d4-a716-446655440000",
          identity_id: "uuid-123",
          notification_preferences: %{email: true, sms: false, push: true}
        })

      assert Parent.has_notification_preferences?(parent)
    end
  end
end
