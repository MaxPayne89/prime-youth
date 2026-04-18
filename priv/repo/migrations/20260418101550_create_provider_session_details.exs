defmodule KlassHero.Repo.Migrations.CreateProviderSessionDetails do
  use Ecto.Migration

  def change do
    create table(:provider_session_details, primary_key: false) do
      add :session_id, :binary_id, primary_key: true
      add :program_id, :binary_id, null: false
      add :program_title, :string, null: false
      add :provider_id, :binary_id, null: false

      add :session_date, :date, null: false
      add :start_time, :time, null: false
      add :end_time, :time, null: false
      add :status, :string, null: false

      add :current_assigned_staff_id, :binary_id
      add :current_assigned_staff_name, :string
      add :cover_staff_id, :binary_id
      add :cover_staff_name, :string

      add :checked_in_count, :integer, null: false, default: 0
      add :total_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:provider_session_details, [:provider_id, :program_id, :session_date])
    create index(:provider_session_details, [:provider_id, :session_date])
  end
end
