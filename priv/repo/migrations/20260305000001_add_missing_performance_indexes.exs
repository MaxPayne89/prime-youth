defmodule KlassHero.Repo.Migrations.AddMissingPerformanceIndexes do
  use Ecto.Migration

  def change do
    create index(:program_sessions, [:session_date])
  end
end
