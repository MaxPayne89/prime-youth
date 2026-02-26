defmodule KlassHero.Repo.Migrations.CreatePrograms do
  use Ecto.Migration

  def up do
    create table(:programs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false, size: 255
      add :description, :text, null: false
      add :age_range, :string, size: 100
      add :price, :decimal, null: false, precision: 10, scale: 2
      add :pricing_period, :string, size: 100
      add :lock_version, :integer, null: false, default: 1
      add :icon_path, :text
      add :category, :string, null: false, default: "education", size: 50
      add :end_date, :date
      add :provider_id, references(:providers, type: :binary_id, on_delete: :nothing)
      add :location, :string, size: 255
      add :cover_image_url, :string, size: 500
      add :instructor_id, references(:staff_members, type: :binary_id, on_delete: :nilify_all)
      add :instructor_name, :string, size: 200
      add :instructor_headshot_url, :string, size: 500
      add :meeting_days, {:array, :string}, null: false, default: []
      add :meeting_start_time, :time
      add :meeting_end_time, :time
      add :start_date, :date
      add :registration_start_date, :date
      add :registration_end_date, :date
      add :season, :string, size: 255

      timestamps(type: :utc_datetime)
    end

    create index(:programs, [:provider_id])
    create index(:programs, [:category])
    create index(:programs, [:end_date])
    create index(:programs, [:inserted_at, :id])

    create constraint(:programs, :price_must_be_non_negative, check: "price >= 0")
  end

  def down do
    drop table(:programs)
  end
end
