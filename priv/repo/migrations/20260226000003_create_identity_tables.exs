defmodule KlassHero.Repo.Migrations.CreateIdentityTables do
  use Ecto.Migration

  def up do
    create table(:parents, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :identity_id, references(:users, type: :binary_id, on_delete: :restrict), null: false

      add :display_name, :string
      add :phone, :string
      add :location, :string
      add :notification_preferences, :map
      add :subscription_tier, :string, null: false, default: "explorer"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:parents, [:identity_id])

    create table(:providers, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :identity_id, references(:users, type: :binary_id, on_delete: :restrict), null: false

      add :business_name, :string, null: false
      add :description, :text
      add :phone, :string
      add :website, :string
      add :address, :string
      add :logo_url, :string
      add :verified, :boolean, default: false, null: false
      add :verified_at, :utc_datetime
      add :categories, {:array, :string}, default: []
      add :subscription_tier, :string, null: false, default: "starter"
      add :verified_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:providers, [:identity_id])
  end

  def down do
    drop table(:providers)
    drop table(:parents)
  end
end
