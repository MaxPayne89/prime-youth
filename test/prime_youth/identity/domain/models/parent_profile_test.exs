defmodule PrimeYouth.Identity.Domain.Models.ParentProfileTest do
  @moduledoc """
  Tests for the ParentProfile domain entity.
  """

  use ExUnit.Case, async: true

  alias PrimeYouth.Identity.Domain.Models.ParentProfile

  describe "new/1 with valid attributes" do
    test "creates parent profile with all fields" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440001",
        display_name: "John Doe",
        phone: "+1234567890",
        location: "New York, NY",
        notification_preferences: %{email: true, sms: false}
      }

      assert {:ok, profile} = ParentProfile.new(attrs)
      assert profile.id == attrs.id
      assert profile.identity_id == attrs.identity_id
      assert profile.display_name == "John Doe"
      assert profile.phone == "+1234567890"
    end

    test "creates parent profile with only required fields" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "660e8400-e29b-41d4-a716-446655440001"
      }

      assert {:ok, profile} = ParentProfile.new(attrs)
      assert is_nil(profile.display_name)
      assert is_nil(profile.phone)
    end
  end

  describe "new/1 validation errors" do
    test "returns error when identity_id is empty" do
      attrs = %{id: "550e8400-e29b-41d4-a716-446655440000", identity_id: ""}

      assert {:error, errors} = ParentProfile.new(attrs)
      assert "Identity ID cannot be empty" in errors
    end

    test "returns error when identity_id is not a string" do
      attrs = %{id: "550e8400-e29b-41d4-a716-446655440000", identity_id: 12345}

      assert {:error, errors} = ParentProfile.new(attrs)
      assert "Identity ID must be a string" in errors
    end

    test "returns error when display_name is empty string" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        display_name: ""
      }

      assert {:error, errors} = ParentProfile.new(attrs)
      assert "Display name cannot be empty if provided" in errors
    end

    test "returns error when display_name exceeds 100 characters" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: "uuid-123",
        display_name: String.duplicate("a", 101)
      }

      assert {:error, errors} = ParentProfile.new(attrs)
      assert "Display name must be 100 characters or less" in errors
    end
  end

  describe "valid?/1" do
    test "returns true for valid parent profile" do
      {:ok, profile} =
        ParentProfile.new(%{
          id: "550e8400-e29b-41d4-a716-446655440000",
          identity_id: "uuid-123"
        })

      assert ParentProfile.valid?(profile)
    end

    test "returns false for parent profile with empty identity_id" do
      profile = %ParentProfile{
        id: "550e8400-e29b-41d4-a716-446655440000",
        identity_id: ""
      }

      refute ParentProfile.valid?(profile)
    end
  end
end
