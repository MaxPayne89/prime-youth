defmodule KlassHero.Repo.Migrations.CreateParticipantPolicies do
  use Ecto.Migration

  def change do
    create table(:participant_policies, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :program_id, references(:programs, type: :binary_id, on_delete: :delete_all),
        null: false

      add :eligibility_at, :string, default: "registration", null: false
      add :min_age_months, :integer
      add :max_age_months, :integer
      add :allowed_genders, {:array, :string}, default: [], null: false
      add :min_grade, :integer
      add :max_grade, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:participant_policies, [:program_id])

    create constraint(:participant_policies, :valid_eligibility_at,
             check: "eligibility_at IN ('registration', 'program_start')"
           )

    create constraint(:participant_policies, :valid_age_range,
             check:
               "min_age_months IS NULL OR max_age_months IS NULL OR min_age_months <= max_age_months"
           )

    create constraint(:participant_policies, :valid_grade_range,
             check: "min_grade IS NULL OR max_grade IS NULL OR min_grade <= max_grade"
           )

    create constraint(:participant_policies, :valid_age_months,
             check: "min_age_months IS NULL OR min_age_months >= 0"
           )

    create constraint(:participant_policies, :valid_grade_bounds,
             check:
               "(min_grade IS NULL OR (min_grade >= 1 AND min_grade <= 13)) AND (max_grade IS NULL OR (max_grade >= 1 AND max_grade <= 13))"
           )
  end
end
