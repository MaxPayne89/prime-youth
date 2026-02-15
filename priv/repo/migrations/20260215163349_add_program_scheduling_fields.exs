defmodule KlassHero.Repo.Migrations.AddProgramSchedulingFields do
  use Ecto.Migration

  def change do
    alter table(:programs) do
      add :meeting_days, {:array, :string}, default: [], null: false
      add :meeting_start_time, :time
      add :meeting_end_time, :time
      add :start_date, :date
      remove :schedule, :string
    end
  end
end
