defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.EnrollmentPolicyRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.EnrollmentPolicyRepository

  describe "upsert/1" do
    test "creates a new policy" do
      program = insert(:program_schema)

      assert {:ok, policy} =
               EnrollmentPolicyRepository.upsert(%{
                 program_id: program.id,
                 min_enrollment: 5,
                 max_enrollment: 20
               })

      assert policy.program_id == to_string(program.id)
      assert policy.min_enrollment == 5
      assert policy.max_enrollment == 20
    end

    test "updates existing policy on conflict" do
      program = insert(:program_schema)

      {:ok, _} =
        EnrollmentPolicyRepository.upsert(%{
          program_id: program.id,
          max_enrollment: 20
        })

      {:ok, updated} =
        EnrollmentPolicyRepository.upsert(%{
          program_id: program.id,
          max_enrollment: 30,
          min_enrollment: 10
        })

      assert updated.max_enrollment == 30
      assert updated.min_enrollment == 10
    end

    test "returns error changeset for invalid data" do
      assert {:error, %Ecto.Changeset{}} =
               EnrollmentPolicyRepository.upsert(%{
                 max_enrollment: 20
               })
    end
  end

  describe "get_by_program_id/1" do
    test "returns policy when it exists" do
      program = insert(:program_schema)
      {:ok, _} = EnrollmentPolicyRepository.upsert(%{program_id: program.id, max_enrollment: 20})

      assert {:ok, policy} = EnrollmentPolicyRepository.get_by_program_id(program.id)
      assert policy.max_enrollment == 20
    end

    test "returns :not_found when no policy exists" do
      assert {:error, :not_found} =
               EnrollmentPolicyRepository.get_by_program_id(Ecto.UUID.generate())
    end
  end

  describe "get_remaining_capacity/1" do
    test "returns :unlimited when no policy exists" do
      assert {:ok, :unlimited} =
               EnrollmentPolicyRepository.get_remaining_capacity(Ecto.UUID.generate())
    end

    test "returns :unlimited when max is nil" do
      program = insert(:program_schema)
      {:ok, _} = EnrollmentPolicyRepository.upsert(%{program_id: program.id, min_enrollment: 5})

      assert {:ok, :unlimited} =
               EnrollmentPolicyRepository.get_remaining_capacity(program.id)
    end

    test "returns remaining spots" do
      program = insert(:program_schema)
      child1 = insert(:child_schema)
      child2 = insert(:child_schema)
      child3 = insert(:child_schema)

      {:ok, _} = EnrollmentPolicyRepository.upsert(%{program_id: program.id, max_enrollment: 10})

      insert(:enrollment_schema, program_id: program.id, child_id: child1.id, status: "pending")
      insert(:enrollment_schema, program_id: program.id, child_id: child2.id, status: "confirmed")
      insert(:enrollment_schema, program_id: program.id, child_id: child3.id, status: "confirmed")

      assert {:ok, 7} = EnrollmentPolicyRepository.get_remaining_capacity(program.id)
    end

    test "does not count cancelled enrollments" do
      program = insert(:program_schema)
      child = insert(:child_schema)

      {:ok, _} = EnrollmentPolicyRepository.upsert(%{program_id: program.id, max_enrollment: 10})
      insert(:enrollment_schema, program_id: program.id, child_id: child.id, status: "cancelled")

      assert {:ok, 10} = EnrollmentPolicyRepository.get_remaining_capacity(program.id)
    end

    test "returns 0 when at capacity (never negative)" do
      program = insert(:program_schema)
      child1 = insert(:child_schema)
      child2 = insert(:child_schema)

      {:ok, _} = EnrollmentPolicyRepository.upsert(%{program_id: program.id, max_enrollment: 1})

      insert(:enrollment_schema, program_id: program.id, child_id: child1.id, status: "pending")
      insert(:enrollment_schema, program_id: program.id, child_id: child2.id, status: "confirmed")

      assert {:ok, 0} = EnrollmentPolicyRepository.get_remaining_capacity(program.id)
    end
  end

  describe "count_active_enrollments/1" do
    test "counts pending and confirmed enrollments" do
      program = insert(:program_schema)
      child1 = insert(:child_schema)
      child2 = insert(:child_schema)
      child3 = insert(:child_schema)

      insert(:enrollment_schema, program_id: program.id, child_id: child1.id, status: "pending")
      insert(:enrollment_schema, program_id: program.id, child_id: child2.id, status: "confirmed")
      insert(:enrollment_schema, program_id: program.id, child_id: child3.id, status: "cancelled")

      assert EnrollmentPolicyRepository.count_active_enrollments(program.id) == 2
    end

    test "returns 0 when no enrollments exist" do
      assert EnrollmentPolicyRepository.count_active_enrollments(Ecto.UUID.generate()) == 0
    end
  end
end
