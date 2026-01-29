defmodule KlassHero.Repo.Migrations.AddStructuredChildFields do
  use Ecto.Migration

  def change do
    alter table(:children) do
      add :emergency_contact, :string, size: 255
      add :support_needs, :text
      add :allergies, :text
    end

    # Trigger: existing notes data needs to be preserved
    # Why: notes is being replaced by structured fields; support_needs is the closest match
    # Outcome: existing notes content is migrated before the column is dropped
    flush()
    execute "UPDATE children SET support_needs = notes WHERE notes IS NOT NULL", ""

    alter table(:children) do
      remove :notes, :text
    end
  end
end
