defmodule KlassHero.Repo.Migrations.CreateProgramStaffParticipants do
  use Ecto.Migration

  def change do
    create table(:program_staff_participants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider_id, :binary_id, null: false
      add :program_id, :binary_id, null: false
      add :staff_user_id, :binary_id, null: false
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:program_staff_participants, [:program_id, :staff_user_id])
    create index(:program_staff_participants, [:provider_id])
    create index(:program_staff_participants, [:staff_user_id])
  end
end
