defmodule KlassHero.Repo.Migrations.CreateProgramListings do
  use Ecto.Migration

  def up do
    create table(:program_listings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :category, :string
      add :age_range, :string
      add :price, :decimal
      add :pricing_period, :string
      add :location, :string
      add :cover_image_url, :string
      add :icon_path, :string
      add :instructor_name, :string
      add :instructor_headshot_url, :string
      add :start_date, :date
      add :end_date, :date
      add :meeting_days, {:array, :string}, default: []
      add :meeting_start_time, :time
      add :meeting_end_time, :time
      add :season, :string
      add :registration_start_date, :date
      add :registration_end_date, :date
      add :provider_id, :binary_id, null: false
      add :provider_verified, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:program_listings, [:inserted_at, :id], name: :program_listings_cursor_idx)
    create index(:program_listings, [:category])
    create index(:program_listings, [:provider_id])
  end

  def down do
    drop table(:program_listings)
  end
end
