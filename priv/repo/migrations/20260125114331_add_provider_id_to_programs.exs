defmodule KlassHero.Repo.Migrations.AddProviderIdToPrograms do
  use Ecto.Migration

  def change do
    alter table(:programs) do
      add :provider_id, references(:providers, type: :binary_id, on_delete: :nothing), null: true
    end

    create index(:programs, [:provider_id])
  end
end
