defmodule KlassHero.Family.Adapters.Driven.Persistence.Repositories.ChildRepositoryTest do
  @moduledoc """
  Tests for the ChildRepository adapter.
  """

  use KlassHero.DataCase, async: true

  alias KlassHero.Family.Adapters.Driven.Persistence.Repositories.ChildRepository
  alias KlassHero.Family.Adapters.Driven.Persistence.Repositories.ParentProfileRepository
  alias KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildGuardianSchema
  alias KlassHero.Family.Domain.Models.Child

  defp create_parent do
    identity_id = Ecto.UUID.generate()
    {:ok, parent} = ParentProfileRepository.create_parent_profile(%{identity_id: identity_id})
    parent
  end

  defp create_child_with_guardian(parent, child_attrs) do
    {:ok, child} = ChildRepository.create(child_attrs)

    Repo.insert!(%ChildGuardianSchema{
      child_id: child.id,
      guardian_id: parent.id,
      relationship: "parent",
      is_primary: true
    })

    child
  end

  describe "create/1" do
    test "creates child and returns domain entity" do
      attrs = %{
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15],
        emergency_contact: "555-1234",
        support_needs: "Extra help with reading",
        allergies: "Peanuts"
      }

      assert {:ok, %Child{} = child} = ChildRepository.create(attrs)
      assert is_binary(child.id)
      assert child.first_name == "Emma"
      assert child.last_name == "Smith"
      assert child.date_of_birth == ~D[2015-06-15]
      assert child.emergency_contact == "555-1234"
      assert child.support_needs == "Extra help with reading"
      assert child.allergies == "Peanuts"
      assert %DateTime{} = child.inserted_at
    end

    test "creates child with minimal fields" do
      attrs = %{
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
      attrs = %{
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

  describe "list_by_guardian/1" do
    test "returns children for guardian ordered by name" do
      parent = create_parent()

      create_child_with_guardian(parent, %{
        first_name: "Zoe",
        last_name: "Smith",
        date_of_birth: ~D[2017-01-01]
      })

      create_child_with_guardian(parent, %{
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15]
      })

      children = ChildRepository.list_by_guardian(parent.id)

      assert length(children) == 2
      assert Enum.at(children, 0).first_name == "Alice"
      assert Enum.at(children, 1).first_name == "Zoe"
    end

    test "returns empty list when guardian has no children" do
      parent = create_parent()

      children = ChildRepository.list_by_guardian(parent.id)

      assert children == []
    end

    test "only returns children for specified guardian" do
      parent1 = create_parent()
      parent2 = create_parent()

      create_child_with_guardian(parent1, %{
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15]
      })

      create_child_with_guardian(parent2, %{
        first_name: "Other",
        last_name: "Child",
        date_of_birth: ~D[2016-01-01]
      })

      children = ChildRepository.list_by_guardian(parent1.id)

      assert length(children) == 1
      assert Enum.at(children, 0).first_name == "Emma"
    end
  end

  describe "create_with_guardian/2" do
    test "creates child and guardian link atomically" do
      parent = create_parent()

      attrs = %{
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15]
      }

      assert {:ok, %Child{} = child} = ChildRepository.create_with_guardian(attrs, parent.id)
      assert child.first_name == "Emma"

      # Verify guardian link was created
      link = Repo.get_by!(ChildGuardianSchema, child_id: child.id, guardian_id: parent.id)
      assert link.relationship == "parent"
      assert link.is_primary == true
    end

    test "returns changeset error for invalid child data" do
      parent = create_parent()

      attrs = %{
        first_name: "",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15]
      }

      assert {:error, %Ecto.Changeset{}} = ChildRepository.create_with_guardian(attrs, parent.id)
    end

    test "rolls back child if guardian link fails" do
      # Use a non-existent guardian_id to trigger FK violation
      non_existent_guardian = Ecto.UUID.generate()

      attrs = %{
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15]
      }

      assert {:error, _changeset} = ChildRepository.create_with_guardian(attrs, non_existent_guardian)

      # Verify child was NOT persisted (transaction rolled back)
      assert [] == Repo.all(KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildSchema)
    end
  end

  describe "child_belongs_to_guardian?/2" do
    test "returns true when guardian link exists" do
      parent = create_parent()
      child = create_child_with_guardian(parent, %{
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15]
      })

      assert ChildRepository.child_belongs_to_guardian?(child.id, parent.id)
    end

    test "returns false when no guardian link exists" do
      {:ok, child} = ChildRepository.create(%{
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15]
      })

      non_existent_guardian = Ecto.UUID.generate()

      refute ChildRepository.child_belongs_to_guardian?(child.id, non_existent_guardian)
    end

    test "returns false for non-existent child" do
      parent = create_parent()
      non_existent_child = Ecto.UUID.generate()

      refute ChildRepository.child_belongs_to_guardian?(non_existent_child, parent.id)
    end
  end

  describe "update/2" do
    test "updates child fields and returns domain entity" do
      {:ok, created} =
        ChildRepository.create(%{
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
      assert {:error, :not_found} =
               ChildRepository.update(Ecto.UUID.generate(), %{first_name: "X"})
    end

    test "returns :not_found for invalid UUID" do
      assert {:error, :not_found} = ChildRepository.update("invalid-uuid", %{first_name: "X"})
    end

    test "returns changeset error for invalid data" do
      {:ok, created} =
        ChildRepository.create(%{
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
      {:ok, created} =
        ChildRepository.create(%{
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
