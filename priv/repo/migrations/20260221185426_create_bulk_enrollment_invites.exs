defmodule KlassHero.Repo.Migrations.CreateBulkEnrollmentInvites do
  use Ecto.Migration

  def change do
    create table(:bulk_enrollment_invites, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :program_id, references(:programs, type: :binary_id, on_delete: :restrict), null: false

      add :provider_id, references(:providers, type: :binary_id, on_delete: :restrict),
        null: false

      # Child info (denormalized from CSV)
      add :child_first_name, :string, size: 100, null: false
      add :child_last_name, :string, size: 100, null: false
      add :child_date_of_birth, :date, null: false

      # Primary guardian
      add :guardian_email, :string, size: 160, null: false
      add :guardian_first_name, :string, size: 100
      add :guardian_last_name, :string, size: 100

      # Secondary guardian (optional)
      add :guardian2_email, :string, size: 160
      add :guardian2_first_name, :string, size: 100
      add :guardian2_last_name, :string, size: 100

      # School info
      add :school_grade, :integer
      add :school_name, :string, size: 255

      # Medical info
      add :medical_conditions, :text
      add :nut_allergy, :boolean, default: false, null: false

      # Consent flags
      add :consent_photo_marketing, :boolean, default: false, null: false
      add :consent_photo_social_media, :boolean, default: false, null: false

      # Invite lifecycle
      add :status, :string, size: 50, null: false, default: "pending"
      add :invite_token, :string
      add :invite_sent_at, :utc_datetime
      add :registered_at, :utc_datetime
      add :enrolled_at, :utc_datetime

      add :enrollment_id, references(:enrollments, type: :binary_id, on_delete: :nilify_all)

      add :error_details, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:bulk_enrollment_invites, [:invite_token],
             where: "invite_token IS NOT NULL"
           )

    create unique_index(
             :bulk_enrollment_invites,
             [:program_id, :guardian_email, :child_first_name, :child_last_name],
             name: :bulk_invites_program_guardian_child_unique
           )

    create index(:bulk_enrollment_invites, [:program_id])
    create index(:bulk_enrollment_invites, [:provider_id])
    create index(:bulk_enrollment_invites, [:status])

    create constraint(:bulk_enrollment_invites, :valid_status,
             check: "status IN ('pending', 'invite_sent', 'registered', 'enrolled', 'failed')"
           )

    create constraint(:bulk_enrollment_invites, :valid_school_grade,
             check: "school_grade IS NULL OR (school_grade >= 1 AND school_grade <= 13)"
           )
  end
end
