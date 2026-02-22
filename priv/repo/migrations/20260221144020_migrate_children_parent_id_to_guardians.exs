defmodule KlassHero.Repo.Migrations.MigrateChildrenParentIdToGuardians do
  use Ecto.Migration

  def up do
    # Trigger: existing children have parent_id FK, new join table is empty
    # Why: preserve existing parent-child relationships in the new structure
    # Outcome: every child gets a primary guardian row in children_guardians
    execute("""
    INSERT INTO children_guardians (id, child_id, guardian_id, relationship, is_primary, inserted_at, updated_at)
    SELECT
      gen_random_uuid(),
      c.id,
      c.parent_id,
      'parent',
      true,
      NOW(),
      NOW()
    FROM children c
    WHERE c.parent_id IS NOT NULL
    """)
  end

  def down do
    execute("DELETE FROM children_guardians")
  end
end
