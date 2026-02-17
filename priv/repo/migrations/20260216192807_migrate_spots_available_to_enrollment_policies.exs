defmodule KlassHero.Repo.Migrations.MigrateSpotsAvailableToEnrollmentPolicies do
  use Ecto.Migration

  def up do
    # Trigger: programs with spots_available > 0 need their capacity migrated
    # Why: enrollment context now owns capacity; this preserves existing data
    # Outcome: enrollment_policies rows created, spots_available column dropped
    execute """
    INSERT INTO enrollment_policies (id, program_id, max_enrollment, inserted_at, updated_at)
    SELECT gen_random_uuid(), id, spots_available, NOW(), NOW()
    FROM programs
    WHERE spots_available > 0
    ON CONFLICT (program_id) DO NOTHING
    """

    alter table(:programs) do
      remove :spots_available
    end
  end

  def down do
    alter table(:programs) do
      add :spots_available, :integer, default: 0, null: false
    end

    execute """
    UPDATE programs p
    SET spots_available = COALESCE(
      (SELECT max_enrollment FROM enrollment_policies ep WHERE ep.program_id = p.id),
      0
    )
    """
  end
end
