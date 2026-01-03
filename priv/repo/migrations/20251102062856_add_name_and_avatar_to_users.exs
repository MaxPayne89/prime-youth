defmodule KlassHero.Repo.Migrations.AddNameAndAvatarToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :name, :string, null: false, default: "User"
      add :avatar, :string
    end
  end
end
