defmodule KlassHero.Enrollment.Adapters.Driven.ACL.ChildInfoACLTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.ACL.ChildInfoACL

  describe "get_children_by_ids/1" do
    test "returns child info maps for existing children" do
      child1 = insert(:child_schema, first_name: "Emma", last_name: "Smith")
      child2 = insert(:child_schema, first_name: "Liam", last_name: "Jones")

      result = ChildInfoACL.get_children_by_ids([child1.id, child2.id])

      assert length(result) == 2

      emma = Enum.find(result, &(&1.id == to_string(child1.id)))
      assert emma.first_name == "Emma"
      assert emma.last_name == "Smith"

      liam = Enum.find(result, &(&1.id == to_string(child2.id)))
      assert liam.first_name == "Liam"
      assert liam.last_name == "Jones"
    end

    test "returns only id, first_name, last_name fields" do
      child = insert(:child_schema)

      [info] = ChildInfoACL.get_children_by_ids([child.id])

      assert Map.keys(info) |> Enum.sort() == [:first_name, :id, :last_name]
    end

    test "returns empty list for empty input" do
      assert ChildInfoACL.get_children_by_ids([]) == []
    end

    test "silently excludes non-existent IDs" do
      child = insert(:child_schema)

      result = ChildInfoACL.get_children_by_ids([child.id, Ecto.UUID.generate()])

      assert length(result) == 1
      assert hd(result).id == to_string(child.id)
    end
  end
end
