defmodule KlassHero.Enrollment.Application.UseCases.ListProgramEnrollmentsTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Application.UseCases.ListProgramEnrollments

  describe "execute/1" do
    test "returns enriched roster entries with child names" do
      program = insert(:program_schema)
      child = insert(:child_schema, first_name: "Emma", last_name: "Smith")

      insert(:enrollment_schema,
        program_id: program.id,
        child_id: child.id,
        parent_id: child.parent_id,
        status: "pending",
        enrolled_at: ~U[2025-06-15 10:00:00Z]
      )

      result = ListProgramEnrollments.execute(program.id)

      assert length(result) == 1
      entry = hd(result)
      assert entry.child_name == "Emma Smith"
      assert entry.status == :pending
      assert entry.enrolled_at == ~U[2025-06-15 10:00:00Z]
      assert is_binary(entry.enrollment_id)
      assert entry.child_id == to_string(child.id)
    end

    test "returns multiple entries for program with multiple enrollments" do
      program = insert(:program_schema)
      child1 = insert(:child_schema, first_name: "Emma", last_name: "Smith")
      child2 = insert(:child_schema, first_name: "Liam", last_name: "Jones")

      insert(:enrollment_schema,
        program_id: program.id,
        child_id: child1.id,
        parent_id: child1.parent_id,
        status: "pending"
      )

      insert(:enrollment_schema,
        program_id: program.id,
        child_id: child2.id,
        parent_id: child2.parent_id,
        status: "confirmed"
      )

      result = ListProgramEnrollments.execute(program.id)

      assert length(result) == 2
      names = Enum.map(result, & &1.child_name) |> Enum.sort()
      assert names == ["Emma Smith", "Liam Jones"]
    end

    test "excludes cancelled enrollments" do
      program = insert(:program_schema)
      child = insert(:child_schema)

      insert(:enrollment_schema,
        program_id: program.id,
        child_id: child.id,
        parent_id: child.parent_id,
        status: "cancelled"
      )

      assert ListProgramEnrollments.execute(program.id) == []
    end

    test "returns empty list for non-existent program" do
      assert ListProgramEnrollments.execute(Ecto.UUID.generate()) == []
    end

    test "returns empty list when program has no enrollments" do
      program = insert(:program_schema)
      assert ListProgramEnrollments.execute(program.id) == []
    end
  end
end
