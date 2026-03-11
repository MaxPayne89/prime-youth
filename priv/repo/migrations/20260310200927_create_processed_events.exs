defmodule KlassHero.Repo.Migrations.CreateProcessedEvents do
  use Ecto.Migration

  def change do
    create table(:processed_events, primary_key: false) do
      add :event_id, :uuid, null: false
      add :handler_ref, :string, null: false
      add :processed_at, :utc_datetime_usec, null: false
    end

    # Composite unique constraint for idempotency: one row per event-handler pair
    create unique_index(:processed_events, [:event_id, :handler_ref])
  end
end
