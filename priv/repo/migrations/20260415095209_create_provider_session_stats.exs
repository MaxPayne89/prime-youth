defmodule KlassHero.Repo.Migrations.CreateProviderSessionStats do
  use Ecto.Migration

  def change do
    create table(:provider_session_stats, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider_id, :binary_id, null: false
      add :program_id, :binary_id, null: false
      add :program_title, :string, null: false
      add :sessions_completed_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:provider_session_stats, [:provider_id, :program_id])
    create index(:provider_session_stats, [:provider_id])
  end
end
