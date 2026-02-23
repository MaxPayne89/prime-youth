defmodule KlassHero.Repo.Migrations.AddSeasonToPrograms do
  use Ecto.Migration

  def change do
    alter table(:programs) do
      add :season, :string, size: 255
    end
  end
end
