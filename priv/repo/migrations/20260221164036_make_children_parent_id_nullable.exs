defmodule KlassHero.Repo.Migrations.MakeChildrenParentIdNullable do
  use Ecto.Migration

  def up do
    # Trigger: domain code no longer writes parent_id on child records
    # Why: guardian relationships are now managed through children_guardians join table
    # Outcome: parent_id becomes nullable so new children can be inserted without it
    alter table(:children) do
      modify :parent_id, :binary_id, null: true, from: {:binary_id, null: false}
    end
  end

  def down do
    alter table(:children) do
      modify :parent_id, :binary_id, null: false, from: {:binary_id, null: true}
    end
  end
end
