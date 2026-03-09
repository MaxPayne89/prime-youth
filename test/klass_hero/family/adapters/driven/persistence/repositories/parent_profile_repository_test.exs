defmodule KlassHero.Family.Adapters.Driven.Persistence.Repositories.ParentProfileRepositoryTest do
  @moduledoc """
  Tests for the ParentProfileRepository adapter.
  """

  use KlassHero.DataCase, async: true

  import KlassHero.AccountsFixtures

  alias KlassHero.Family.Adapters.Driven.Persistence.Repositories.ParentProfileRepository
  alias KlassHero.Family.Domain.Models.ParentProfile

  describe "create_parent_profile/1" do
    test "creates parent profile and returns domain entity" do
      user = unconfirmed_user_fixture(intended_roles: [:parent])

      attrs = %{
        identity_id: user.id,
        display_name: "John Doe",
        phone: "+1234567890",
        location: "New York, NY",
        notification_preferences: %{email: true, sms: false}
      }

      assert {:ok, %ParentProfile{} = profile} =
               ParentProfileRepository.create_parent_profile(attrs)

      assert is_binary(profile.id)
      assert profile.identity_id == attrs.identity_id
      assert profile.display_name == "John Doe"
      assert profile.phone == "+1234567890"
      assert %DateTime{} = profile.inserted_at
    end

    test "creates parent profile with minimal fields" do
      user = unconfirmed_user_fixture(intended_roles: [:parent])
      attrs = %{identity_id: user.id}

      assert {:ok, %ParentProfile{} = profile} =
               ParentProfileRepository.create_parent_profile(attrs)

      assert is_binary(profile.id)
      assert is_nil(profile.display_name)
    end

    test "returns :duplicate_resource error when profile exists" do
      user = unconfirmed_user_fixture(intended_roles: [:parent])
      identity_id = user.id
      attrs = %{identity_id: identity_id}

      assert {:ok, _} = ParentProfileRepository.create_parent_profile(attrs)
      assert {:error, :duplicate_resource} = ParentProfileRepository.create_parent_profile(attrs)
    end
  end

  describe "get_by_identity_id/1" do
    test "retrieves existing parent profile" do
      user = unconfirmed_user_fixture(intended_roles: [:parent])
      identity_id = user.id
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

  describe "list_by_ids/1" do
    test "returns parent profiles matching the given IDs" do
      user1 = unconfirmed_user_fixture(intended_roles: [:parent])
      user2 = unconfirmed_user_fixture(intended_roles: [:parent])
      user3 = unconfirmed_user_fixture(intended_roles: [:parent])

      {:ok, parent1} = ParentProfileRepository.create_parent_profile(%{identity_id: user1.id})
      {:ok, parent2} = ParentProfileRepository.create_parent_profile(%{identity_id: user2.id})
      {:ok, _other} = ParentProfileRepository.create_parent_profile(%{identity_id: user3.id})

      result = ParentProfileRepository.list_by_ids([parent1.id, parent2.id])

      ids = Enum.map(result, & &1.id) |> Enum.sort()
      assert ids == Enum.sort([parent1.id, parent2.id])
    end

    test "returns empty list for empty input" do
      assert ParentProfileRepository.list_by_ids([]) == []
    end

    test "silently excludes non-existent IDs" do
      user = unconfirmed_user_fixture(intended_roles: [:parent])
      {:ok, parent} = ParentProfileRepository.create_parent_profile(%{identity_id: user.id})

      result = ParentProfileRepository.list_by_ids([parent.id, Ecto.UUID.generate()])

      assert length(result) == 1
      assert hd(result).id == parent.id
    end
  end

  describe "has_profile?/1" do
    test "returns true when profile exists" do
      user = unconfirmed_user_fixture(intended_roles: [:parent])
      identity_id = user.id
      {:ok, _} = ParentProfileRepository.create_parent_profile(%{identity_id: identity_id})

      assert ParentProfileRepository.has_profile?(identity_id) == true
    end

    test "returns false when profile does not exist" do
      non_existent_id = Ecto.UUID.generate()

      assert ParentProfileRepository.has_profile?(non_existent_id) == false
    end
  end
end
