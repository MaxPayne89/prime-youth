defmodule KlassHero.Repo.Migrations.CreateProgramStaffAssignments do
  use Ecto.Migration

  def change do
    create table(:program_staff_assignments, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :provider_id, references(:providers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :program_id, references(:programs, type: :binary_id, on_delete: :delete_all),
        null: false

      add :staff_member_id, references(:staff_members, type: :binary_id, on_delete: :delete_all),
        null: false

      add :assigned_at, :utc_datetime_usec, null: false
      add :unassigned_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:program_staff_assignments, [:provider_id])
    create index(:program_staff_assignments, [:program_id])
    create index(:program_staff_assignments, [:staff_member_id])

    create unique_index(:program_staff_assignments, [:program_id, :staff_member_id],
             where: "unassigned_at IS NULL",
             name: :program_staff_assignments_active_unique
           )
  end
end
