defmodule KlassHero.Repo.Migrations.CreateParticipationRecords do
  use Ecto.Migration

  def change do
    create table(:participation_records, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :session_id,
          references(:program_sessions, type: :binary_id, on_delete: :restrict),
          null: false

      # child_id: Future FK to children table - using binary_id but no constraint yet
      add :child_id, :binary_id, null: false

      add :parent_id,
          references(:parents, type: :binary_id, on_delete: :nilify_all),
          null: true

      add :provider_id,
          references(:providers, type: :binary_id, on_delete: :nilify_all),
          null: true

      # Status tracking
      add :status, :string, null: false, size: 50

      # Check-in data
      add :check_in_at, :utc_datetime
      add :check_in_notes, :text
      # user_id of person who checked in
      add :check_in_by, :binary_id

      # Check-out data
      add :check_out_at, :utc_datetime
      add :check_out_notes, :text
      # user_id of person who checked out
      add :check_out_by, :binary_id

      # Optimistic locking for concurrent updates
      add :lock_version, :integer, default: 1, null: false

      timestamps(type: :utc_datetime)
    end

    # Indexes for common queries
    create index(:participation_records, [:session_id])
    create index(:participation_records, [:child_id])
    create index(:participation_records, [:parent_id])
    create index(:participation_records, [:provider_id])
    create index(:participation_records, [:status])

    # Unique constraint: one participation record per child per session
    create unique_index(:participation_records, [:session_id, :child_id])

    # Check constraint: cannot check out before checking in
    create constraint(:participation_records, :check_out_after_check_in,
             check: "check_out_at IS NULL OR check_in_at IS NULL OR check_out_at >= check_in_at"
           )
  end
end
