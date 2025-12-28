defmodule PrimeYouth.Parenting.Adapters.Driven.Persistence.Repositories.ParentRepositoryTest do
  @moduledoc """
  Tests for the ParentRepository adapter.

  Tests database operations for parent profiles including creation,
  retrieval, and existence checks.
  """

  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.Parenting.Adapters.Driven.Persistence.Repositories.ParentRepository
  alias PrimeYouth.Parenting.Domain.Models.Parent

  # =============================================================================
  # create_parent_profile/1
  # =============================================================================

  describe "create_parent_profile/1" do
    test "creates parent with all fields and returns domain entity" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        display_name: "John Doe",
        phone: "+1234567890",
        location: "New York, NY",
        notification_preferences: %{email: true, sms: false}
      }

      assert {:ok, %Parent{} = parent} = ParentRepository.create_parent_profile(attrs)
      assert is_binary(parent.id)
      assert parent.identity_id == attrs.identity_id
      assert parent.display_name == "John Doe"
      assert parent.phone == "+1234567890"
      assert parent.location == "New York, NY"
      assert parent.notification_preferences == %{email: true, sms: false}
      assert %DateTime{} = parent.inserted_at
      assert %DateTime{} = parent.updated_at
    end

    test "creates parent with minimal fields (identity_id only)" do
      attrs = %{identity_id: Ecto.UUID.generate()}

      assert {:ok, %Parent{} = parent} = ParentRepository.create_parent_profile(attrs)
      assert is_binary(parent.id)
      assert parent.identity_id == attrs.identity_id
      assert is_nil(parent.display_name)
      assert is_nil(parent.phone)
      assert is_nil(parent.location)
      assert is_nil(parent.notification_preferences)
    end

    test "auto-generates UUID for id field" do
      attrs = %{identity_id: Ecto.UUID.generate()}

      assert {:ok, %Parent{} = parent} = ParentRepository.create_parent_profile(attrs)
      assert {:ok, _} = Ecto.UUID.cast(parent.id)
    end

    test "returns :duplicate_identity error when profile exists for identity_id" do
      identity_id = Ecto.UUID.generate()
      attrs = %{identity_id: identity_id, display_name: "First Parent"}

      assert {:ok, _first_parent} = ParentRepository.create_parent_profile(attrs)

      second_attrs = %{identity_id: identity_id, display_name: "Second Parent"}
      assert {:error, :duplicate_identity} = ParentRepository.create_parent_profile(second_attrs)
    end

    test "allows creating profiles with different identity_ids" do
      first_attrs = %{identity_id: Ecto.UUID.generate(), display_name: "First Parent"}
      second_attrs = %{identity_id: Ecto.UUID.generate(), display_name: "Second Parent"}

      assert {:ok, first_parent} = ParentRepository.create_parent_profile(first_attrs)
      assert {:ok, second_parent} = ParentRepository.create_parent_profile(second_attrs)

      assert first_parent.id != second_parent.id
      assert first_parent.identity_id != second_parent.identity_id
    end
  end

  # =============================================================================
  # get_by_identity_id/1
  # =============================================================================

  describe "get_by_identity_id/1" do
    test "retrieves existing parent and returns domain entity" do
      identity_id = Ecto.UUID.generate()

      attrs = %{
        identity_id: identity_id,
        display_name: "Jane Doe",
        phone: "+1987654321",
        location: "Los Angeles, CA",
        notification_preferences: %{push: true}
      }

      {:ok, created_parent} = ParentRepository.create_parent_profile(attrs)

      assert {:ok, %Parent{} = retrieved_parent} =
               ParentRepository.get_by_identity_id(identity_id)

      assert retrieved_parent.id == created_parent.id
      assert retrieved_parent.identity_id == identity_id
      assert retrieved_parent.display_name == "Jane Doe"
      assert retrieved_parent.phone == "+1987654321"
      assert retrieved_parent.location == "Los Angeles, CA"
      assert retrieved_parent.notification_preferences == %{"push" => true}
    end

    test "returns :not_found for non-existent identity_id" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = ParentRepository.get_by_identity_id(non_existent_id)
    end

    test "retrieves correct parent when multiple exist" do
      first_identity = Ecto.UUID.generate()
      second_identity = Ecto.UUID.generate()

      {:ok, _first} =
        ParentRepository.create_parent_profile(%{
          identity_id: first_identity,
          display_name: "First"
        })

      {:ok, second} =
        ParentRepository.create_parent_profile(%{
          identity_id: second_identity,
          display_name: "Second"
        })

      assert {:ok, retrieved} = ParentRepository.get_by_identity_id(second_identity)
      assert retrieved.id == second.id
      assert retrieved.display_name == "Second"
    end
  end

  # =============================================================================
  # has_profile?/1
  # =============================================================================

  describe "has_profile?/1" do
    test "returns true when parent profile exists" do
      identity_id = Ecto.UUID.generate()
      {:ok, _parent} = ParentRepository.create_parent_profile(%{identity_id: identity_id})

      assert ParentRepository.has_profile?(identity_id) == true
    end

    test "returns false when parent profile does not exist" do
      non_existent_id = Ecto.UUID.generate()

      assert ParentRepository.has_profile?(non_existent_id) == false
    end

    test "returns correct result after creating multiple profiles" do
      existing_identity = Ecto.UUID.generate()
      non_existing_identity = Ecto.UUID.generate()

      {:ok, _} = ParentRepository.create_parent_profile(%{identity_id: existing_identity})

      assert ParentRepository.has_profile?(existing_identity) == true
      assert ParentRepository.has_profile?(non_existing_identity) == false
    end
  end
end
