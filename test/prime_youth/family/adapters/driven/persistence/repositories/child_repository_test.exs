defmodule PrimeYouth.Family.Adapters.Driven.Persistence.Repositories.ChildRepositoryTest do
  @moduledoc """
  Tests for the ChildRepository persistence layer.

  Verifies database operations, error handling, and domain entity conversion.
  """

  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Family.Adapters.Driven.Persistence.Repositories.ChildRepository
  alias PrimeYouth.Family.Domain.Models.Child

  # =============================================================================
  # get_by_id/1
  # =============================================================================

  describe "get_by_id/1" do
    test "retrieves existing child by id" do
      schema =
        insert(:child_schema,
          first_name: "Alice",
          last_name: "Smith",
          date_of_birth: ~D[2018-06-15],
          notes: "Loves soccer"
        )

      assert {:ok, %Child{} = child} = ChildRepository.get_by_id(schema.id)
      assert child.id == schema.id
      assert child.parent_id == schema.parent_id
      assert child.first_name == "Alice"
      assert child.last_name == "Smith"
      assert child.date_of_birth == ~D[2018-06-15]
      assert child.notes == "Loves soccer"
    end

    test "returns Child domain entity with all fields populated" do
      schema =
        insert(:child_schema,
          first_name: "Bob",
          last_name: "Johnson",
          date_of_birth: ~D[2017-03-10],
          notes: "Enjoys art"
        )

      assert {:ok, %Child{} = child} = ChildRepository.get_by_id(schema.id)
      assert is_binary(child.id)
      assert is_binary(child.parent_id)
      assert is_binary(child.first_name)
      assert is_binary(child.last_name)
      assert match?(%Date{}, child.date_of_birth)
      assert is_binary(child.notes)
      assert match?(%DateTime{}, child.inserted_at)
      assert match?(%DateTime{}, child.updated_at)
    end

    test "returns :not_found for non-existent id" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = ChildRepository.get_by_id(non_existent_id)
    end

    test "returns :not_found for invalid UUID format" do
      invalid_id = "not-a-valid-uuid"

      assert {:error, :not_found} = ChildRepository.get_by_id(invalid_id)
    end
  end

  # =============================================================================
  # create/1
  # =============================================================================

  describe "create/1" do
    test "creates child with all fields and returns domain entity" do
      parent_schema = insert(:parent_schema)

      attrs = %{
        parent_id: parent_schema.id,
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: ~D[2018-06-15],
        notes: "Loves soccer"
      }

      assert {:ok, %Child{} = child} = ChildRepository.create(attrs)
      assert is_binary(child.id)
      assert child.parent_id == parent_schema.id
      assert child.first_name == "Alice"
      assert child.last_name == "Smith"
      assert child.date_of_birth == ~D[2018-06-15]
      assert child.notes == "Loves soccer"
      assert match?(%DateTime{}, child.inserted_at)
      assert match?(%DateTime{}, child.updated_at)
    end

    test "creates child with minimal fields (parent_id, first_name, last_name, date_of_birth)" do
      parent_schema = insert(:parent_schema)

      attrs = %{
        parent_id: parent_schema.id,
        first_name: "Bob",
        last_name: "Johnson",
        date_of_birth: ~D[2019-02-20]
      }

      assert {:ok, %Child{} = child} = ChildRepository.create(attrs)
      assert is_binary(child.id)
      assert child.parent_id == parent_schema.id
      assert child.first_name == "Bob"
      assert child.last_name == "Johnson"
      assert child.date_of_birth == ~D[2019-02-20]
      assert is_nil(child.notes)
    end

    test "auto-generates UUID for id field" do
      parent_schema = insert(:parent_schema)

      attrs = %{
        parent_id: parent_schema.id,
        first_name: "Charlie",
        last_name: "Brown",
        date_of_birth: ~D[2020-05-10]
      }

      assert {:ok, %Child{} = child} = ChildRepository.create(attrs)
      assert is_binary(child.id)
      assert String.length(child.id) == 36
      assert String.contains?(child.id, "-")
    end

    test "auto-generates inserted_at and updated_at timestamps" do
      parent_schema = insert(:parent_schema)

      attrs = %{
        parent_id: parent_schema.id,
        first_name: "Diana",
        last_name: "Prince",
        date_of_birth: ~D[2017-08-15]
      }

      assert {:ok, %Child{} = child} = ChildRepository.create(attrs)
      assert match?(%DateTime{}, child.inserted_at)
      assert match?(%DateTime{}, child.updated_at)
      refute is_nil(child.inserted_at)
      refute is_nil(child.updated_at)
    end

    test "returns :database_query_error for missing required fields" do
      attrs = %{
        first_name: "Alice",
        last_name: "Smith"
      }

      assert {:error, :database_query_error} = ChildRepository.create(attrs)
    end

    test "returns :database_query_error for invalid date_of_birth (future)" do
      parent_schema = insert(:parent_schema)
      future_date = Date.add(Date.utc_today(), 1)

      attrs = %{
        parent_id: parent_schema.id,
        first_name: "Alice",
        last_name: "Smith",
        date_of_birth: future_date
      }

      assert {:error, :database_query_error} = ChildRepository.create(attrs)
    end
  end

  # =============================================================================
  # list_by_parent/1
  # =============================================================================

  describe "list_by_parent/1" do
    test "returns list of children for given parent_id" do
      parent_schema = insert(:parent_schema)

      child1 = insert(:child_schema, parent_id: parent_schema.id, first_name: "Alice")
      child2 = insert(:child_schema, parent_id: parent_schema.id, first_name: "Bob")
      child3 = insert(:child_schema, parent_id: parent_schema.id, first_name: "Charlie")

      assert {:ok, children} = ChildRepository.list_by_parent(parent_schema.id)

      assert length(children) == 3
      assert Enum.all?(children, &match?(%Child{}, &1))
      assert Enum.all?(children, &(&1.parent_id == parent_schema.id))

      child_ids = Enum.map(children, & &1.id) |> Enum.sort()
      expected_ids = [child1.id, child2.id, child3.id] |> Enum.sort()
      assert child_ids == expected_ids
    end

    test "returns empty list when parent has no children" do
      parent_id = Ecto.UUID.generate()

      assert {:ok, []} = ChildRepository.list_by_parent(parent_id)
    end

    test "orders children by first_name ASC, then last_name ASC" do
      parent_schema = insert(:parent_schema)

      _charlie =
        insert(:child_schema,
          parent_id: parent_schema.id,
          first_name: "Charlie",
          last_name: "Brown"
        )

      _alice_smith =
        insert(:child_schema,
          parent_id: parent_schema.id,
          first_name: "Alice",
          last_name: "Smith"
        )

      _alice_jones =
        insert(:child_schema,
          parent_id: parent_schema.id,
          first_name: "Alice",
          last_name: "Jones"
        )

      _bob =
        insert(:child_schema, parent_id: parent_schema.id, first_name: "Bob", last_name: "Davis")

      assert {:ok, children} = ChildRepository.list_by_parent(parent_schema.id)

      assert length(children) == 4
      assert Enum.at(children, 0).first_name == "Alice"
      assert Enum.at(children, 0).last_name == "Jones"
      assert Enum.at(children, 1).first_name == "Alice"
      assert Enum.at(children, 1).last_name == "Smith"
      assert Enum.at(children, 2).first_name == "Bob"
      assert Enum.at(children, 2).last_name == "Davis"
      assert Enum.at(children, 3).first_name == "Charlie"
      assert Enum.at(children, 3).last_name == "Brown"
    end

    test "returns children with same first_name ordered by last_name" do
      parent_schema = insert(:parent_schema)

      _alice_smith =
        insert(:child_schema,
          parent_id: parent_schema.id,
          first_name: "Alice",
          last_name: "Smith"
        )

      _alice_brown =
        insert(:child_schema,
          parent_id: parent_schema.id,
          first_name: "Alice",
          last_name: "Brown"
        )

      _alice_jones =
        insert(:child_schema,
          parent_id: parent_schema.id,
          first_name: "Alice",
          last_name: "Jones"
        )

      assert {:ok, children} = ChildRepository.list_by_parent(parent_schema.id)

      assert length(children) == 3
      assert Enum.all?(children, &(&1.first_name == "Alice"))
      assert Enum.at(children, 0).last_name == "Brown"
      assert Enum.at(children, 1).last_name == "Jones"
      assert Enum.at(children, 2).last_name == "Smith"
    end

    test "returns only children for specified parent_id (not other parents)" do
      parent1_schema = insert(:parent_schema)
      parent2_schema = insert(:parent_schema)

      child1 = insert(:child_schema, parent_id: parent1_schema.id, first_name: "Alice")
      child2 = insert(:child_schema, parent_id: parent1_schema.id, first_name: "Bob")
      _child3 = insert(:child_schema, parent_id: parent2_schema.id, first_name: "Charlie")
      _child4 = insert(:child_schema, parent_id: parent2_schema.id, first_name: "Diana")

      assert {:ok, children} = ChildRepository.list_by_parent(parent1_schema.id)

      assert length(children) == 2
      assert Enum.all?(children, &(&1.parent_id == parent1_schema.id))

      child_ids = Enum.map(children, & &1.id) |> Enum.sort()
      expected_ids = [child1.id, child2.id] |> Enum.sort()
      assert child_ids == expected_ids
    end
  end
end
