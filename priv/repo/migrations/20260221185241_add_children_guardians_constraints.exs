defmodule KlassHero.Repo.Migrations.AddChildrenGuardiansConstraints do
  use Ecto.Migration

  def change do
    # Trigger: multiple is_primary=true per child is currently possible
    # Why: exactly one primary guardian per child is a business invariant
    # Outcome: DB prevents multiple primary guardians for the same child
    create unique_index(:children_guardians, [:child_id],
             where: "is_primary = true",
             name: :children_guardians_one_primary_per_child
           )

    # Trigger: relationship column accepts any string value at DB level
    # Why: only parent/guardian/other are valid domain values
    # Outcome: DB rejects invalid relationship strings
    create constraint(:children_guardians, :valid_relationship,
             check: "relationship IN ('parent', 'guardian', 'other')"
           )
  end
end
