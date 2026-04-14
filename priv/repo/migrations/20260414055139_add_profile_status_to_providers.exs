defmodule KlassHero.Repo.Migrations.AddProfileStatusToProviders do
  use Ecto.Migration

  def change do
    alter table(:providers) do
      add :profile_status, :string, default: "active", null: false
    end
  end
end
