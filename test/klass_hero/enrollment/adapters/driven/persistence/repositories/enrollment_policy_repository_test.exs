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

  describe "get_policies_by_program_ids/1" do
    test "returns empty map for empty list" do
      assert EnrollmentPolicyRepository.get_policies_by_program_ids([]) == %{}
    end

    test "returns policies keyed by program_id" do
      program1 = insert(:program_schema)
      program2 = insert(:program_schema)

      {:ok, _} =
        EnrollmentPolicyRepository.upsert(%{program_id: program1.id, max_enrollment: 20})

      {:ok, _} =
        EnrollmentPolicyRepository.upsert(%{
          program_id: program2.id,
          min_enrollment: 5,
          max_enrollment: 30
        })

      result =
        EnrollmentPolicyRepository.get_policies_by_program_ids([
          to_string(program1.id),
          to_string(program2.id)
        ])

      assert map_size(result) == 2
      assert result[to_string(program1.id)].max_enrollment == 20
      assert result[to_string(program2.id)].min_enrollment == 5
      assert result[to_string(program2.id)].max_enrollment == 30
    end

    test "omits programs without policies" do
      program = insert(:program_schema)
      missing_id = Ecto.UUID.generate()

      {:ok, _} =
        EnrollmentPolicyRepository.upsert(%{program_id: program.id, max_enrollment: 10})

      result =
        EnrollmentPolicyRepository.get_policies_by_program_ids([
          to_string(program.id),
          missing_id
        ])

      assert map_size(result) == 1
      assert Map.has_key?(result, to_string(program.id))
      refute Map.has_key?(result, missing_id)
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
