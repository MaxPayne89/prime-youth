defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentPolicySchemaTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentPolicySchema

  describe "changeset/2" do
    test "valid with program_id and max_enrollment" do
      changeset =
        EnrollmentPolicySchema.changeset(%{
          program_id: Ecto.UUID.generate(),
          max_enrollment: 20
        })

      assert changeset.valid?
    end

    test "valid with program_id and min_enrollment" do
      changeset =
        EnrollmentPolicySchema.changeset(%{
          program_id: Ecto.UUID.generate(),
          min_enrollment: 5
        })

      assert changeset.valid?
    end

    test "valid with both min and max enrollment" do
      changeset =
        EnrollmentPolicySchema.changeset(%{
          program_id: Ecto.UUID.generate(),
          min_enrollment: 5,
          max_enrollment: 20
        })

      assert changeset.valid?
    end

    test "invalid without program_id" do
      changeset = EnrollmentPolicySchema.changeset(%{max_enrollment: 20})
      refute changeset.valid?
      assert %{program_id: _} = errors_on(changeset)
    end

    test "invalid when min < 1" do
      changeset =
        EnrollmentPolicySchema.changeset(%{
          program_id: Ecto.UUID.generate(),
          min_enrollment: 0
        })

      refute changeset.valid?
    end

    test "invalid when max < 1" do
      changeset =
        EnrollmentPolicySchema.changeset(%{
          program_id: Ecto.UUID.generate(),
          max_enrollment: 0
        })

      refute changeset.valid?
    end

    test "invalid when min > max" do
      changeset =
        EnrollmentPolicySchema.changeset(%{
          program_id: Ecto.UUID.generate(),
          min_enrollment: 25,
          max_enrollment: 10
        })

      refute changeset.valid?
    end
  end
end
