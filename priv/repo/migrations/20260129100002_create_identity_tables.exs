defmodule KlassHero.Repo.Migrations.CreateIdentityTables do
  use Ecto.Migration

  def change do
    create table(:parents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :identity_id, :binary_id, null: false
      add :display_name, :string
      add :phone, :string
      add :location, :string
      add :notification_preferences, :map
      add :subscription_tier, :string, null: false, default: "explorer"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:parents, [:identity_id])
    create index(:parents, [:subscription_tier])

    create table(:providers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :identity_id, :binary_id, null: false
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

      timestamps(type: :utc_datetime)
    end

    create unique_index(:providers, [:identity_id])
    create index(:providers, [:subscription_tier])
  end
end
