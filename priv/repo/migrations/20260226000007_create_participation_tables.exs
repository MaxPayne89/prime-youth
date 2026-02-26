defmodule KlassHero.Repo.Migrations.CreateParticipationTables do
  use Ecto.Migration

  def up do
    create table(:program_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :program_id, references(:programs, type: :binary_id, on_delete: :restrict), null: false

      add :session_date, :date, null: false
      add :start_time, :time, null: false
      add :end_time, :time, null: false
      add :max_capacity, :integer, null: false
      add :status, :string, null: false, size: 50
      add :location, :string, size: 255
      add :notes, :text
      add :lock_version, :integer, null: false, default: 1

      timestamps(type: :utc_datetime)
    end

    create unique_index(:program_sessions, [:program_id, :session_date, :start_time])

    create constraint(:program_sessions, :max_capacity_must_be_non_negative,
             check: "max_capacity >= 0"
           )

    create constraint(:program_sessions, :end_time_must_be_after_start_time,
             check: "end_time > start_time"
           )

    create table(:participation_records, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :session_id, references(:program_sessions, type: :binary_id, on_delete: :restrict),
        null: false

      add :child_id, references(:children, type: :binary_id, on_delete: :restrict), null: false

      add :parent_id, references(:parents, type: :binary_id, on_delete: :nilify_all)
      add :provider_id, references(:providers, type: :binary_id, on_delete: :nilify_all)
      add :status, :string, null: false, size: 50
      add :check_in_at, :utc_datetime
      add :check_in_notes, :text
      add :check_in_by, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :check_out_at, :utc_datetime
      add :check_out_notes, :text
      add :check_out_by, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :lock_version, :integer, null: false, default: 1

      timestamps(type: :utc_datetime)
    end

    create unique_index(:participation_records, [:session_id, :child_id])
    create index(:participation_records, [:child_id])
    create index(:participation_records, [:status])

    create constraint(:participation_records, :check_out_must_be_after_check_in,
             check: "check_out_at IS NULL OR check_in_at IS NULL OR check_out_at >= check_in_at"
           )

    create table(:behavioral_notes, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :participation_record_id,
          references(:participation_records, type: :binary_id, on_delete: :delete_all),
          null: false

      add :child_id, references(:children, type: :binary_id, on_delete: :nothing), null: false

      add :parent_id, references(:parents, type: :binary_id, on_delete: :nilify_all)

      add :provider_id, references(:providers, type: :binary_id, on_delete: :nilify_all),
        null: false

      add :content, :text, null: false
      add :status, :string, null: false, size: 50
      add :rejection_reason, :text
      add :submitted_at, :utc_datetime, null: false
      add :reviewed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:behavioral_notes, [:participation_record_id, :provider_id])
    create index(:behavioral_notes, [:child_id])
    create index(:behavioral_notes, [:parent_id])
    create index(:behavioral_notes, [:status])
  end

  def down do
    drop table(:behavioral_notes)
    drop table(:participation_records)
    drop table(:program_sessions)
  end
end
