defmodule KlassHero.Repo.Migrations.AddEndDateToPrograms do
  use Ecto.Migration

  def change do
    alter table(:programs) do
      add :end_date, :utc_datetime, null: true
    end

    create index(:programs, [:end_date])
  end
end
