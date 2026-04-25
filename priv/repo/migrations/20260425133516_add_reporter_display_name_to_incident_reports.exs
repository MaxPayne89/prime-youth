defmodule KlassHero.Repo.Migrations.AddReporterDisplayNameToIncidentReports do
  use Ecto.Migration

  def up do
    alter table(:incident_reports) do
      add :reporter_display_name, :string
    end

    flush()

    execute("""
    UPDATE incident_reports
    SET reporter_display_name = COALESCE(NULLIF(TRIM(users.name), ''), users.email)
    FROM users
    WHERE incident_reports.reporter_user_id = users.id
      AND incident_reports.reporter_display_name IS NULL
    """)
  end

  def down do
    alter table(:incident_reports) do
      remove :reporter_display_name
    end
  end
end
