defmodule KlassHero.Repo.Migrations.CreateChildrenGuardians do
  use Ecto.Migration

  def change do
    create table(:children_guardians, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :child_id, references(:children, type: :binary_id, on_delete: :delete_all), null: false

      add :guardian_id, references(:parents, type: :binary_id, on_delete: :delete_all),
        null: false

      add :relationship, :string, size: 50, null: false, default: "parent"
      add :is_primary, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:children_guardians, [:child_id, :guardian_id])
    create index(:children_guardians, [:guardian_id])
  end
end
