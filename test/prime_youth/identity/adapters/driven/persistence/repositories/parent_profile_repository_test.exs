defmodule PrimeYouth.Identity.Adapters.Driven.Persistence.Repositories.ParentProfileRepositoryTest do
  @moduledoc """
  Tests for the ParentProfileRepository adapter.
  """

  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.Identity.Adapters.Driven.Persistence.Repositories.ParentProfileRepository
  alias PrimeYouth.Identity.Domain.Models.ParentProfile

  describe "create_parent_profile/1" do
    test "creates parent profile and returns domain entity" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        display_name: "John Doe",
        phone: "+1234567890",
        location: "New York, NY",
        notification_preferences: %{email: true, sms: false}
      }

      assert {:ok, %ParentProfile{} = profile} = ParentProfileRepository.create_parent_profile(attrs)
      assert is_binary(profile.id)
      assert profile.identity_id == attrs.identity_id
      assert profile.display_name == "John Doe"
      assert profile.phone == "+1234567890"
      assert %DateTime{} = profile.inserted_at
    end

    test "creates parent profile with minimal fields" do
      attrs = %{identity_id: Ecto.UUID.generate()}

      assert {:ok, %ParentProfile{} = profile} = ParentProfileRepository.create_parent_profile(attrs)
      assert is_binary(profile.id)
      assert is_nil(profile.display_name)
    end

    test "returns :duplicate_identity error when profile exists" do
      identity_id = Ecto.UUID.generate()
      attrs = %{identity_id: identity_id}

      assert {:ok, _} = ParentProfileRepository.create_parent_profile(attrs)
      assert {:error, :duplicate_identity} = ParentProfileRepository.create_parent_profile(attrs)
    end
  end

  describe "get_by_identity_id/1" do
    test "retrieves existing parent profile" do
      identity_id = Ecto.UUID.generate()
      attrs = %{identity_id: identity_id, display_name: "Jane Doe"}

      {:ok, created} = ParentProfileRepository.create_parent_profile(attrs)

      assert {:ok, %ParentProfile{} = retrieved} =
               ParentProfileRepository.get_by_identity_id(identity_id)

      assert retrieved.id == created.id
      assert retrieved.display_name == "Jane Doe"
    end

    test "returns :not_found for non-existent identity_id" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = ParentProfileRepository.get_by_identity_id(non_existent_id)
    end
  end

  describe "has_profile?/1" do
    test "returns true when profile exists" do
      identity_id = Ecto.UUID.generate()
      {:ok, _} = ParentProfileRepository.create_parent_profile(%{identity_id: identity_id})

      assert ParentProfileRepository.has_profile?(identity_id) == true
    end

    test "returns false when profile does not exist" do
      non_existent_id = Ecto.UUID.generate()

      assert ParentProfileRepository.has_profile?(non_existent_id) == false
    end
  end
end
