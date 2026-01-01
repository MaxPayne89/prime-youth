defmodule KlassHero.Repo.Migrations.CreatePrograms do
  use Ecto.Migration

  def change do
    create table(:programs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false, size: 255
      add :description, :text, null: false
      add :schedule, :string, null: false, size: 255
      add :age_range, :string, null: false, size: 100
      add :price, :decimal, null: false, precision: 10, scale: 2
      add :pricing_period, :string, null: false, size: 100
      add :spots_available, :integer, null: false, default: 0
      add :lock_version, :integer, null: false, default: 1
      add :gradient_class, :string, size: 255
      add :icon_path, :text

      timestamps(type: :utc_datetime)
    end

    # Index on title for sorting and future search capabilities
    create index(:programs, [:title])

    # Check constraints for business rules
    create constraint(:programs, :price_must_be_non_negative, check: "price >= 0")

    create constraint(:programs, :spots_available_must_be_non_negative,
             check: "spots_available >= 0"
           )
  end
end
