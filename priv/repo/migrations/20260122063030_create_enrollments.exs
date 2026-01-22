defmodule KlassHero.Repo.Migrations.CreateEnrollments do
  use Ecto.Migration

  def change do
    create table(:enrollments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :program_id, references(:programs, type: :binary_id, on_delete: :restrict), null: false
      add :child_id, references(:children, type: :binary_id, on_delete: :restrict), null: false
      add :parent_id, references(:parents, type: :binary_id, on_delete: :restrict), null: false

      add :status, :string, null: false, size: 20
      add :enrolled_at, :utc_datetime, null: false
      add :confirmed_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :cancelled_at, :utc_datetime
      add :cancellation_reason, :text

      add :subtotal, :decimal, precision: 10, scale: 2
      add :vat_amount, :decimal, precision: 10, scale: 2
      add :card_fee_amount, :decimal, precision: 10, scale: 2
      add :total_amount, :decimal, precision: 10, scale: 2
      add :payment_method, :string, size: 20
      add :special_requirements, :text

      timestamps(type: :utc_datetime)
    end

    create index(:enrollments, [:parent_id])
    create index(:enrollments, [:child_id])
    create index(:enrollments, [:program_id])
    create index(:enrollments, [:parent_id, :enrolled_at])

    create unique_index(:enrollments, [:program_id, :child_id],
             where: "status IN ('pending', 'confirmed')",
             name: :enrollments_program_child_active_index
           )
  end
end
