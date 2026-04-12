defmodule KlassHero.Repo.Migrations.AddOriginToPrograms do
  use Ecto.Migration

  def change do
    alter table(:programs) do
      add :origin, :string, null: false, default: "self_posted"
    end

    create index(:programs, [:provider_id, :origin])
  end
end
