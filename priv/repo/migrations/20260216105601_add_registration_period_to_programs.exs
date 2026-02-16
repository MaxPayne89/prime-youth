defmodule KlassHero.Repo.Migrations.AddRegistrationPeriodToPrograms do
  use Ecto.Migration

  def change do
    alter table(:programs) do
      add :registration_start_date, :date
      add :registration_end_date, :date
    end
  end
end
