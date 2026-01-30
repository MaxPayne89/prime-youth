defmodule KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ChildRepositoryTest do
  @moduledoc """
  Tests for the ChildRepository adapter.
  """

  use KlassHero.DataCase, async: true

  alias KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ChildRepository
  alias KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ParentProfileRepository
  alias KlassHero.Identity.Domain.Models.Child

  defp create_parent do
    identity_id = Ecto.UUID.generate()
    {:ok, parent} = ParentProfileRepository.create_parent_profile(%{identity_id: identity_id})
    parent
  end

  describe "create/1" do
    test "creates child and returns domain entity" do
      parent = create_parent()

      attrs = %{
        parent_id: parent.id,
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15],
        emergency_contact: "555-1234",
        support_needs: "Extra help with reading",
        allergies: "Peanuts"
      }

      assert {:ok, %Child{} = child} = ChildRepository.create(attrs)
      assert is_binary(child.id)
      assert child.parent_id == parent.id
      assert child.first_name == "Emma"
      assert child.last_name == "Smith"
      assert child.date_of_birth == ~D[2015-06-15]
      assert child.emergency_contact == "555-1234"
      assert child.support_needs == "Extra help with reading"
      assert child.allergies == "Peanuts"
      assert %DateTime{} = child.inserted_at
    end

    test "creates child with minimal fields" do
      parent = create_parent()

      attrs = %{
        parent_id: parent.id,
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15]
      }

      assert {:ok, %Child{} = child} = ChildRepository.create(attrs)
      assert is_nil(child.emergency_contact)
      assert is_nil(child.support_needs)
      assert is_nil(child.allergies)
    end
  end

  describe "get_by_id/1" do
    test "retrieves existing child" do
      parent = create_parent()

      attrs = %{
        parent_id: parent.id,
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15]
      }

      {:ok, created} = ChildRepository.create(attrs)

      assert {:ok, %Child{} = retrieved} = ChildRepository.get_by_id(created.id)
      assert retrieved.id == created.id
      assert retrieved.first_name == "Emma"
    end

    test "returns :not_found for non-existent id" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = ChildRepository.get_by_id(non_existent_id)
    end

    test "returns :not_found for invalid UUID" do
      assert {:error, :not_found} = ChildRepository.get_by_id("invalid-uuid")
    end
  end

  describe "list_by_parent/1" do
    test "returns children for parent ordered by name" do
      parent = create_parent()

      {:ok, _} =
        ChildRepository.create(%{
          parent_id: parent.id,
          first_name: "Zoe",
          last_name: "Smith",
          date_of_birth: ~D[2017-01-01]
        })

      {:ok, _} =
        ChildRepository.create(%{
          parent_id: parent.id,
          first_name: "Alice",
          last_name: "Smith",
          date_of_birth: ~D[2015-06-15]
        })

      children = ChildRepository.list_by_parent(parent.id)

      assert length(children) == 2
      assert Enum.at(children, 0).first_name == "Alice"
      assert Enum.at(children, 1).first_name == "Zoe"
    end

    test "returns empty list when parent has no children" do
      parent = create_parent()

      children = ChildRepository.list_by_parent(parent.id)

      assert children == []
    end

    test "only returns children for specified parent" do
      parent1 = create_parent()
      parent2 = create_parent()

      {:ok, _} =
        ChildRepository.create(%{
          parent_id: parent1.id,
          first_name: "Emma",
          last_name: "Smith",
          date_of_birth: ~D[2015-06-15]
        })

      {:ok, _} =
        ChildRepository.create(%{
          parent_id: parent2.id,
          first_name: "Other",
          last_name: "Child",
          date_of_birth: ~D[2016-01-01]
        })

      children = ChildRepository.list_by_parent(parent1.id)

      assert length(children) == 1
      assert Enum.at(children, 0).first_name == "Emma"
    end
  end

  describe "update/2" do
    test "updates child fields and returns domain entity" do
      parent = create_parent()

      {:ok, created} =
        ChildRepository.create(%{
          parent_id: parent.id,
          first_name: "Emma",
          last_name: "Smith",
          date_of_birth: ~D[2015-06-15]
        })

      assert {:ok, %Child{} = updated} =
               ChildRepository.update(created.id, %{first_name: "Emily", allergies: "Peanuts"})

      assert updated.id == created.id
      assert updated.first_name == "Emily"
      assert updated.last_name == "Smith"
      assert updated.allergies == "Peanuts"
    end

    test "returns :not_found for non-existent child" do
      assert {:error, :not_found} = ChildRepository.update(Ecto.UUID.generate(), %{first_name: "X"})
    end

    test "returns :not_found for invalid UUID" do
      assert {:error, :not_found} = ChildRepository.update("invalid-uuid", %{first_name: "X"})
    end

    test "returns changeset error for invalid data" do
      parent = create_parent()

      {:ok, created} =
        ChildRepository.create(%{
          parent_id: parent.id,
          first_name: "Emma",
          last_name: "Smith",
          date_of_birth: ~D[2015-06-15]
        })

      assert {:error, %Ecto.Changeset{}} =
               ChildRepository.update(created.id, %{first_name: ""})
    end
  end

  describe "delete/1" do
    test "deletes existing child" do
      parent = create_parent()

      {:ok, created} =
        ChildRepository.create(%{
          parent_id: parent.id,
          first_name: "Emma",
          last_name: "Smith",
          date_of_birth: ~D[2015-06-15]
        })

      assert :ok = ChildRepository.delete(created.id)
      assert {:error, :not_found} = ChildRepository.get_by_id(created.id)
    end

    test "returns :not_found for non-existent child" do
      assert {:error, :not_found} = ChildRepository.delete(Ecto.UUID.generate())
    end

    test "returns :not_found for invalid UUID" do
      assert {:error, :not_found} = ChildRepository.delete("invalid-uuid")
    end
  end
end
