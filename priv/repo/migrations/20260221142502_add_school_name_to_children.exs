defmodule KlassHero.Repo.Migrations.AddSchoolNameToChildren do
  use Ecto.Migration

  def change do
    alter table(:children) do
      add :school_name, :string, size: 255
    end
  end
end
