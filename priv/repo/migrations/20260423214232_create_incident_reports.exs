defmodule KlassHero.Repo.Migrations.CreateIncidentReports do
  use Ecto.Migration

  def change do
    create table(:incident_reports, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :provider_id, references(:providers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :reporter_user_id, references(:users, type: :binary_id, on_delete: :restrict),
        null: false

      add :program_id, references(:programs, type: :binary_id, on_delete: :nilify_all)
      add :session_id, references(:program_sessions, type: :binary_id, on_delete: :nilify_all)

      add :category, :string, null: false
      add :severity, :string, null: false
      add :description, :text, null: false
      add :occurred_at, :utc_datetime, null: false
      add :photo_url, :string
      add :original_filename, :string

      timestamps(type: :utc_datetime)
    end

    create index(:incident_reports, [:provider_id])
    create index(:incident_reports, [:program_id])
    create index(:incident_reports, [:session_id])
    create index(:incident_reports, [:severity])

    create constraint(:incident_reports, :one_of_program_or_session,
             check:
               "(program_id IS NOT NULL AND session_id IS NULL) OR (program_id IS NULL AND session_id IS NOT NULL)"
           )

    create constraint(:incident_reports, :category_check,
             check:
               "category IN ('safety_concern','behavioral_issue','injury','property_damage','policy_violation','other')"
           )

    create constraint(:incident_reports, :severity_check,
             check: "severity IN ('low','medium','high','critical')"
           )
  end
end
