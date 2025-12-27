defmodule PrimeYouth.Repo.Migrations.CreateProgramSessions do
  use Ecto.Migration

  def change do
    create table(:program_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :program_id,
          references(:programs, type: :binary_id, on_delete: :restrict),
          null: false

      add :session_date, :date, null: false
      add :start_time, :time, null: false
      add :end_time, :time, null: false
      add :max_capacity, :integer, null: false
      add :status, :string, null: false, size: 50
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    # Indexes for common queries
    create index(:program_sessions, [:program_id])
    create index(:program_sessions, [:session_date])
    create index(:program_sessions, [:status])
    create index(:program_sessions, [:program_id, :session_date])

    # Unique constraint: one program cannot have duplicate sessions at same date/time
    create unique_index(:program_sessions, [:program_id, :session_date, :start_time])

    # Check constraints for business rules
    create constraint(:program_sessions, :max_capacity_must_be_non_negative,
             check: "max_capacity >= 0"
           )

    create constraint(:program_sessions, :end_time_after_start_time,
             check: "end_time > start_time"
           )
  end
end
