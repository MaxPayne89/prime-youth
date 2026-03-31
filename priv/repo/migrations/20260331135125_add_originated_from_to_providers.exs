defmodule KlassHero.Repo.Migrations.AddOriginatedFromToProviders do
  use Ecto.Migration

  def change do
    alter table(:providers) do
      add :originated_from, :string
    end
  end
end
