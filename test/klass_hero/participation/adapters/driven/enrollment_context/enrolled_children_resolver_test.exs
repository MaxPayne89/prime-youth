defmodule KlassHero.Participation.Adapters.Driven.EnrollmentContext.EnrolledChildrenResolverTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Participation.Adapters.Driven.EnrollmentContext.EnrolledChildrenResolver

  describe "list_enrolled_child_ids/1" do
    test "returns child IDs for children with active enrollments in the program" do
      enrollment = insert(:enrollment_schema, status: "confirmed")

      result = EnrolledChildrenResolver.list_enrolled_child_ids(enrollment.program_id)

      assert result == [enrollment.child_id]
    end

    test "returns empty list when no enrollments exist" do
      result = EnrolledChildrenResolver.list_enrolled_child_ids(Ecto.UUID.generate())

      assert result == []
    end

    test "excludes children from other programs" do
      enrollment = insert(:enrollment_schema, status: "confirmed")
      _other_enrollment = insert(:enrollment_schema, status: "confirmed")

      result = EnrolledChildrenResolver.list_enrolled_child_ids(enrollment.program_id)

      assert result == [enrollment.child_id]
    end
  end
end
