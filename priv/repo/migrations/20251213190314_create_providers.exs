defmodule KlassHero.Repo.Migrations.CreateProviders do
  use Ecto.Migration

  def change do
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

      timestamps(type: :utc_datetime)
    end

    create unique_index(:providers, [:identity_id])
  end
end
