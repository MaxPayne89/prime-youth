defmodule KlassHero.Repo.Migrations.CreateConsents do
  use Ecto.Migration

  def change do
    create table(:consents, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :parent_id, references(:parents, type: :binary_id, on_delete: :restrict), null: false

      add :child_id, references(:children, type: :binary_id, on_delete: :restrict), null: false

      add :consent_type, :string, size: 100, null: false
      add :granted_at, :utc_datetime, null: false
      add :withdrawn_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:consents, [:child_id])
    create index(:consents, [:parent_id])
    create index(:consents, [:child_id, :consent_type])
  end
end
