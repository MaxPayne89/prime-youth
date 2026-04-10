defmodule KlassHero.Enrollment.Application.UseCases.ListEnrolledChildFirstNamesForParentTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Application.UseCases.ListEnrolledChildFirstNamesForParent

  describe "execute/2" do
    test "returns child first names for a parent enrolled in a program" do
      program = insert(:program_schema)
      {child, parent} = insert_child_with_guardian(first_name: "Emma", last_name: "Smith")

      insert(:enrollment_schema,
        program_id: program.id,
        child_id: child.id,
        parent_id: parent.id,
        status: "pending"
      )

      result = ListEnrolledChildFirstNamesForParent.execute(program.id, to_string(parent.identity_id))

      assert result == ["Emma"]
    end

    test "returns multiple first names when parent has multiple children enrolled" do
      program = insert(:program_schema)
      {child1, parent} = insert_child_with_guardian(first_name: "Emma", last_name: "Smith")
      child2 = insert(:child_schema, first_name: "Liam", last_name: "Smith")
      insert(:child_guardian_schema, child_id: child2.id, guardian_id: parent.id)

      insert(:enrollment_schema,
        program_id: program.id,
        child_id: child1.id,
        parent_id: parent.id,
        status: "pending"
      )

      insert(:enrollment_schema,
        program_id: program.id,
        child_id: child2.id,
        parent_id: parent.id,
        status: "confirmed"
      )

      result = ListEnrolledChildFirstNamesForParent.execute(program.id, to_string(parent.identity_id))

      assert Enum.sort(result) == ["Emma", "Liam"]
    end

    test "returns only children for the specified parent when multiple parents are enrolled" do
      program = insert(:program_schema)
      {child1, parent1} = insert_child_with_guardian(first_name: "Emma", last_name: "Smith")
      {child2, parent2} = insert_child_with_guardian(first_name: "Liam", last_name: "Jones")

      insert(:enrollment_schema,
        program_id: program.id,
        child_id: child1.id,
        parent_id: parent1.id,
        status: "pending"
      )

      insert(:enrollment_schema,
        program_id: program.id,
        child_id: child2.id,
        parent_id: parent2.id,
        status: "pending"
      )

      result = ListEnrolledChildFirstNamesForParent.execute(program.id, to_string(parent1.identity_id))

      assert result == ["Emma"]
    end

    test "returns empty list when parent has no enrollments in the program" do
      program = insert(:program_schema)
      {other_child, other_parent} = insert_child_with_guardian()
      {_child, target_parent} = insert_child_with_guardian()

      insert(:enrollment_schema,
        program_id: program.id,
        child_id: other_child.id,
        parent_id: other_parent.id,
        status: "pending"
      )

      result = ListEnrolledChildFirstNamesForParent.execute(program.id, to_string(target_parent.identity_id))

      assert result == []
    end

    test "returns empty list when program has no enrollments" do
      program = insert(:program_schema)
      parent_user_id = Ecto.UUID.generate()

      assert ListEnrolledChildFirstNamesForParent.execute(program.id, parent_user_id) == []
    end

    test "returns empty list for unknown parent_user_id" do
      program = insert(:program_schema)
      {child, parent} = insert_child_with_guardian()

      insert(:enrollment_schema,
        program_id: program.id,
        child_id: child.id,
        parent_id: parent.id,
        status: "pending"
      )

      unknown_user_id = Ecto.UUID.generate()

      assert ListEnrolledChildFirstNamesForParent.execute(program.id, unknown_user_id) == []
    end
  end
end
