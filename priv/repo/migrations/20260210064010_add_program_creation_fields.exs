defmodule KlassHero.Repo.Migrations.AddProgramCreationFields do
  use Ecto.Migration

  def change do
    alter table(:programs) do
      add :location, :string, size: 255
      add :cover_image_url, :string, size: 500
      add :instructor_id, references(:staff_members, type: :binary_id, on_delete: :nilify_all)
      add :instructor_name, :string, size: 200
      add :instructor_headshot_url, :string, size: 500

      # Relax existing required columns to allow nil (for creation form that omits them)
      modify :schedule, :string, null: true
      modify :age_range, :string, null: true
      modify :pricing_period, :string, null: true
    end

    create index(:programs, [:instructor_id])
  end
end
