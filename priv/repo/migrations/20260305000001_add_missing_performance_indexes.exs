defmodule KlassHero.Repo.Migrations.AddMissingPerformanceIndexes do
  use Ecto.Migration

  def change do
    create index(:program_sessions, [:session_date])
    create index(:participation_records, [:provider_id])
  end
end
