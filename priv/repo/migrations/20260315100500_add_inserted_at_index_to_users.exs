defmodule KlassHero.Repo.Migrations.AddInsertedAtIndexToUsers do
  use Ecto.Migration

  def change do
    create index(:users, [:inserted_at])
  end
end
