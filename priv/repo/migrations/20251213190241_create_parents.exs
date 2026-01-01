defmodule KlassHero.Repo.Migrations.CreateParents do
  use Ecto.Migration

  def change do
    create table(:parents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :identity_id, :binary_id, null: false
      add :display_name, :string
      add :phone, :string
      add :location, :string
      add :notification_preferences, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:parents, [:identity_id])
  end
end
