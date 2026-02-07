defmodule KlassHero.Repo.Migrations.AddVerifiedByIdToProviders do
  use Ecto.Migration

  def change do
    alter table(:providers) do
      add :verified_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
