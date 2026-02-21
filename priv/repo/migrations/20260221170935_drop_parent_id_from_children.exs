defmodule KlassHero.Repo.Migrations.DropParentIdFromChildren do
  use Ecto.Migration

  def up do
    # Trigger: parent_id column is no longer referenced by any domain code
    # Why: guardian relationships are fully managed through children_guardians join table
    # Outcome: removes the legacy parent_id column and its index from the children table
    drop_if_exists index(:children, [:parent_id])

    alter table(:children) do
      remove :parent_id
    end
  end

  def down do
    alter table(:children) do
      add :parent_id, references(:parents, type: :binary_id, on_delete: :restrict)
    end

    create index(:children, [:parent_id])

    # Trigger: restoring parent_id from join table for rollback
    # Why: down migration must restore the previous schema state
    # Outcome: first primary guardian becomes the parent_id
    execute """
    UPDATE children c
    SET parent_id = cg.guardian_id
    FROM children_guardians cg
    WHERE cg.child_id = c.id AND cg.is_primary = true
    """
  end
end
