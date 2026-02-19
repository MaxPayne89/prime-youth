defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.ParticipantPolicySchemaTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.ParticipantPolicySchema

  describe "changeset/2" do
    test "valid with only program_id (all optionals nil)" do
      changeset =
        ParticipantPolicySchema.changeset(%{
          program_id: Ecto.UUID.generate()
        })

      assert changeset.valid?
    end

    test "valid with all fields set" do
      changeset =
        ParticipantPolicySchema.changeset(%{
          program_id: Ecto.UUID.generate(),
          eligibility_at: "program_start",
          min_age_months: 48,
          max_age_months: 120,
          allowed_genders: ["male", "female"],
          min_grade: 1,
          max_grade: 6
        })

      assert changeset.valid?
    end

    test "invalid without program_id" do
      changeset = ParticipantPolicySchema.changeset(%{max_age_months: 120})
      refute changeset.valid?
      assert %{program_id: _} = errors_on(changeset)
    end

    test "invalid with unknown eligibility_at value" do
      changeset =
        ParticipantPolicySchema.changeset(%{
          program_id: Ecto.UUID.generate(),
          eligibility_at: "unknown"
        })

      refute changeset.valid?
      assert %{eligibility_at: _} = errors_on(changeset)
    end

    test "invalid with bad gender values in allowed_genders" do
      changeset =
        ParticipantPolicySchema.changeset(%{
          program_id: Ecto.UUID.generate(),
          allowed_genders: ["male", "alien"]
        })

      refute changeset.valid?
      assert %{allowed_genders: _} = errors_on(changeset)
    end

    test "invalid when min_age_months exceeds max_age_months" do
      changeset =
        ParticipantPolicySchema.changeset(%{
          program_id: Ecto.UUID.generate(),
          min_age_months: 120,
          max_age_months: 48
        })

      refute changeset.valid?
      assert %{min_age_months: _} = errors_on(changeset)
    end

    test "invalid when min_grade exceeds max_grade" do
      changeset =
        ParticipantPolicySchema.changeset(%{
          program_id: Ecto.UUID.generate(),
          min_grade: 10,
          max_grade: 3
        })

      refute changeset.valid?
      assert %{min_grade: _} = errors_on(changeset)
    end

    test "invalid when min_age_months is negative" do
      changeset =
        ParticipantPolicySchema.changeset(%{
          program_id: Ecto.UUID.generate(),
          min_age_months: -1
        })

      refute changeset.valid?
      assert %{min_age_months: _} = errors_on(changeset)
    end

    test "invalid when grade is outside 1-13 range" do
      changeset =
        ParticipantPolicySchema.changeset(%{
          program_id: Ecto.UUID.generate(),
          min_grade: 0
        })

      refute changeset.valid?
      assert %{min_grade: _} = errors_on(changeset)

      changeset2 =
        ParticipantPolicySchema.changeset(%{
          program_id: Ecto.UUID.generate(),
          max_grade: 14
        })

      refute changeset2.valid?
      assert %{max_grade: _} = errors_on(changeset2)
    end
  end
end
