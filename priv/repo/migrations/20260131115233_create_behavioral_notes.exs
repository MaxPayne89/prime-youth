defmodule KlassHero.Repo.Migrations.CreateBehavioralNotes do
  use Ecto.Migration

  def change do
    create table(:behavioral_notes, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :participation_record_id,
          references(:participation_records, type: :binary_id, on_delete: :delete_all),
          null: false

      add :child_id, references(:children, type: :binary_id, on_delete: :nothing), null: false
      add :parent_id, :binary_id
      add :provider_id, :binary_id, null: false
      add :content, :text, null: false
      add :status, :string, size: 50, null: false
      add :rejection_reason, :text
      add :submitted_at, :utc_datetime, null: false
      add :reviewed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:behavioral_notes, [:participation_record_id])
    create index(:behavioral_notes, [:child_id])
    create index(:behavioral_notes, [:parent_id])
    create index(:behavioral_notes, [:status])
    create unique_index(:behavioral_notes, [:participation_record_id, :provider_id])
  end
end
