defmodule KlassHero.Repo.Migrations.CreateEnrollmentPolicies do
  use Ecto.Migration

  def change do
    create table(:enrollment_policies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :program_id, references(:programs, type: :binary_id, on_delete: :delete_all), null: false
      add :min_enrollment, :integer
      add :max_enrollment, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:enrollment_policies, [:program_id])

    create constraint(:enrollment_policies, :min_enrollment_positive,
             check: "min_enrollment IS NULL OR min_enrollment >= 1")

    create constraint(:enrollment_policies, :max_enrollment_positive,
             check: "max_enrollment IS NULL OR max_enrollment >= 1")

    create constraint(:enrollment_policies, :min_not_exceeds_max,
             check: "min_enrollment IS NULL OR max_enrollment IS NULL OR min_enrollment <= max_enrollment")
  end
end
