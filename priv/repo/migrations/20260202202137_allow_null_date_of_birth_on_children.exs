defmodule KlassHero.Repo.Migrations.AllowNullDateOfBirthOnChildren do
  use Ecto.Migration

  def change do
    alter table(:children) do
      modify :date_of_birth, :date, null: true, from: {:date, null: false}
    end
  end
end
