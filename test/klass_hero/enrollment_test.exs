defmodule KlassHero.EnrollmentTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment

  describe "get_enrollment_summary_batch/1" do
    test "returns enrolled 0 and capacity nil when no policy exists" do
      program = insert(:program_schema)

      result = Enrollment.get_enrollment_summary_batch([program.id])

      assert result[program.id] == %{enrolled: 0, capacity: nil}
    end

    test "returns enrolled count and total capacity for capped policy" do
      program = insert(:program_schema)

      {:ok, _policy} =
        Enrollment.set_enrollment_policy(%{
          program_id: program.id,
          max_enrollment: 10
        })

      insert(:enrollment_schema, program_id: program.id, status: "pending")
      insert(:enrollment_schema, program_id: program.id, status: "confirmed")

      result = Enrollment.get_enrollment_summary_batch([program.id])

      assert result[program.id] == %{enrolled: 2, capacity: 10}
    end

    test "returns capacity nil for unlimited policy (min_enrollment only)" do
      program = insert(:program_schema)

      {:ok, _policy} =
        Enrollment.set_enrollment_policy(%{
          program_id: program.id,
          min_enrollment: 3
        })

      insert(:enrollment_schema, program_id: program.id, status: "confirmed")

      result = Enrollment.get_enrollment_summary_batch([program.id])

      assert result[program.id] == %{enrolled: 1, capacity: nil}
    end

    test "handles mixed programs in a single batch" do
      capped = insert(:program_schema)
      unlimited = insert(:program_schema)
      no_policy = insert(:program_schema)

      {:ok, _} =
        Enrollment.set_enrollment_policy(%{
          program_id: capped.id,
          max_enrollment: 5
        })

      {:ok, _} =
        Enrollment.set_enrollment_policy(%{
          program_id: unlimited.id,
          min_enrollment: 2
        })

      insert(:enrollment_schema, program_id: capped.id, status: "pending")
      insert(:enrollment_schema, program_id: capped.id, status: "confirmed")
      insert(:enrollment_schema, program_id: unlimited.id, status: "confirmed")

      result =
        Enrollment.get_enrollment_summary_batch([capped.id, unlimited.id, no_policy.id])

      assert result[capped.id] == %{enrolled: 2, capacity: 5}
      assert result[unlimited.id] == %{enrolled: 1, capacity: nil}
      assert result[no_policy.id] == %{enrolled: 0, capacity: nil}
    end

    test "returns capacity equal to enrolled when fully booked" do
      program = insert(:program_schema)

      {:ok, _} =
        Enrollment.set_enrollment_policy(%{
          program_id: program.id,
          max_enrollment: 2
        })

      insert(:enrollment_schema, program_id: program.id, status: "pending")
      insert(:enrollment_schema, program_id: program.id, status: "confirmed")

      result = Enrollment.get_enrollment_summary_batch([program.id])

      # Trigger: capacity == enrolled when remaining is 0
      # Why: max_enrollment(2) - active(2) = 0 remaining, so capacity = 2 + 0 = 2
      assert result[program.id] == %{enrolled: 2, capacity: 2}
    end
  end
end
