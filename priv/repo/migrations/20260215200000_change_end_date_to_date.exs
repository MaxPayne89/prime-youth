defmodule KlassHero.Repo.Migrations.ChangeEndDateToDate do
  use Ecto.Migration

  def change do
    alter table(:programs) do
      modify :end_date, :date, from: :utc_datetime
    end
  end
end
