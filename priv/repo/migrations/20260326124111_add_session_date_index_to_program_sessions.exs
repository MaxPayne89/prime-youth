defmodule KlassHero.Repo.Migrations.AddSessionDateIndexToProgramSessions do
  use Ecto.Migration

  def change do
    create index(:program_sessions, [:session_date])
  end
end
