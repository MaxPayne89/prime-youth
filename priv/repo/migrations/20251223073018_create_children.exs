defmodule PrimeYouth.Repo.Migrations.CreateChildren do
  use Ecto.Migration

  def change do
    create table(:children, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :parent_id, references(:parents, type: :binary_id, on_delete: :restrict), null: false
      add :first_name, :string, size: 100, null: false
      add :last_name, :string, size: 100, null: false
      add :date_of_birth, :date, null: false
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:children, [:parent_id])

    # Add FK constraint from attendance_records.child_id to children.id
    alter table(:attendance_records) do
      modify :child_id, references(:children, type: :binary_id, on_delete: :restrict),
        from: {:binary_id, null: false}
    end
  end
end
