defmodule KlassHero.Repo.Migrations.CreateEnrollmentTables do
  use Ecto.Migration

  def up do
    create table(:enrollments, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :program_id, references(:programs, type: :binary_id, on_delete: :restrict), null: false

      add :child_id, references(:children, type: :binary_id, on_delete: :restrict), null: false

      add :parent_id, references(:parents, type: :binary_id, on_delete: :restrict), null: false

      add :status, :string, null: false, size: 20
      add :enrolled_at, :utc_datetime, null: false
      add :confirmed_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :cancelled_at, :utc_datetime
      add :cancellation_reason, :text
      add :subtotal, :decimal, precision: 10, scale: 2
      add :vat_amount, :decimal, precision: 10, scale: 2
      add :card_fee_amount, :decimal, precision: 10, scale: 2
      add :total_amount, :decimal, precision: 10, scale: 2
      add :payment_method, :string, size: 20
      add :special_requirements, :text

      timestamps(type: :utc_datetime)
    end

    create index(:enrollments, [:parent_id])
    create index(:enrollments, [:child_id])
    create index(:enrollments, [:program_id])
    create index(:enrollments, [:enrolled_at])

    create unique_index(:enrollments, [:program_id, :child_id],
             where: "status IN ('pending', 'confirmed')",
             name: :enrollments_program_child_active_index
           )

    create table(:enrollment_policies, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :program_id, references(:programs, type: :binary_id, on_delete: :delete_all),
        null: false

      add :min_enrollment, :integer
      add :max_enrollment, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:enrollment_policies, [:program_id])

    create constraint(:enrollment_policies, :min_enrollment_positive,
             check: "min_enrollment IS NULL OR min_enrollment >= 1"
           )

    create constraint(:enrollment_policies, :max_enrollment_positive,
             check: "max_enrollment IS NULL OR max_enrollment >= 1"
           )

    create constraint(:enrollment_policies, :min_not_exceeds_max,
             check:
               "min_enrollment IS NULL OR max_enrollment IS NULL OR min_enrollment <= max_enrollment"
           )

    create table(:participant_policies, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :program_id, references(:programs, type: :binary_id, on_delete: :delete_all),
        null: false

      add :eligibility_at, :string, null: false, default: "registration"
      add :min_age_months, :integer
      add :max_age_months, :integer
      add :allowed_genders, {:array, :string}, null: false, default: []
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

    create table(:bulk_enrollment_invites, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :program_id, references(:programs, type: :binary_id, on_delete: :restrict), null: false

      add :provider_id, references(:providers, type: :binary_id, on_delete: :restrict),
        null: false

      add :child_first_name, :string, null: false, size: 100
      add :child_last_name, :string, null: false, size: 100
      add :child_date_of_birth, :date, null: false
      add :guardian_email, :string, null: false, size: 160
      add :guardian_first_name, :string, size: 100
      add :guardian_last_name, :string, size: 100
      add :guardian2_email, :string, size: 160
      add :guardian2_first_name, :string, size: 100
      add :guardian2_last_name, :string, size: 100
      add :school_grade, :integer
      add :school_name, :string, size: 255
      add :medical_conditions, :text
      add :nut_allergy, :boolean, null: false, default: false
      add :consent_photo_marketing, :boolean, null: false, default: false
      add :consent_photo_social_media, :boolean, null: false, default: false
      add :status, :string, null: false, size: 50, default: "pending"
      add :invite_token, :string
      add :invite_sent_at, :utc_datetime
      add :registered_at, :utc_datetime
      add :enrolled_at, :utc_datetime
      add :enrollment_id, references(:enrollments, type: :binary_id, on_delete: :nilify_all)
      add :error_details, :text

      timestamps(type: :utc_datetime)
    end

    create index(:bulk_enrollment_invites, [:program_id])
    create index(:bulk_enrollment_invites, [:status])

    create unique_index(:bulk_enrollment_invites, [:invite_token],
             where: "invite_token IS NOT NULL"
           )

    create constraint(:bulk_enrollment_invites, :valid_status,
             check: "status IN ('pending', 'invite_sent', 'registered', 'enrolled', 'failed')"
           )

    create constraint(:bulk_enrollment_invites, :valid_school_grade,
             check: "school_grade IS NULL OR (school_grade >= 1 AND school_grade <= 13)"
           )

    execute """
    CREATE UNIQUE INDEX bulk_invites_program_guardian_child_unique
    ON bulk_enrollment_invites (program_id, LOWER(guardian_email), LOWER(child_first_name), LOWER(child_last_name))
    """
  end

  def down do
    drop table(:bulk_enrollment_invites)
    drop table(:participant_policies)
    drop table(:enrollment_policies)
    drop table(:enrollments)
  end
end
