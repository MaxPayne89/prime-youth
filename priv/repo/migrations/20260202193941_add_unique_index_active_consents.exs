defmodule KlassHero.Repo.Migrations.AddUniqueIndexActiveConsents do
  use Ecto.Migration

  def change do
    # Trigger: no database-level enforcement of "one active consent per child+type"
    # Why: race conditions could create duplicate active consents without this constraint
    # Outcome: only one non-withdrawn consent per (child_id, consent_type) allowed
    create unique_index(:consents, [:child_id, :consent_type],
             where: "withdrawn_at IS NULL",
             name: :consents_active_child_consent_type_index
           )
  end
end
