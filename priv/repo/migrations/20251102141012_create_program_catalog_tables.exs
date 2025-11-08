defmodule PrimeYouth.Repo.Migrations.CreateProgramCatalogTables do
  use Ecto.Migration

  def change do
    # Enable pg_trgm extension for trigram-based fuzzy search
    execute("CREATE EXTENSION IF NOT EXISTS pg_trgm", "DROP EXTENSION IF EXISTS pg_trgm")

    # Table: providers
    create table(:providers, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:name, :string, null: false, size: 200)
      add(:description, :text)
      add(:email, :string, null: false, size: 255)
      add(:phone, :string, size: 50)
      add(:website, :string, size: 255)
      add(:credentials, :text)
      add(:logo_url, :string, size: 255)
      add(:is_verified, :boolean, null: false, default: false)
      add(:is_prime_youth, :boolean, null: false, default: false)
      add(:user_id, references(:users, on_delete: :restrict, type: :binary_id), null: false)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:providers, [:user_id]))
    create(index(:providers, [:is_prime_youth]))

    # Table: programs
    create table(:programs, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:title, :string, null: false, size: 200)
      add(:description, :text, null: false)

      add(:provider_id, references(:providers, on_delete: :restrict, type: :binary_id),
        null: false
      )

      add(:category, :string, null: false, size: 50)
      add(:secondary_categories, {:array, :string})
      add(:age_min, :integer, null: false)
      add(:age_max, :integer, null: false)
      add(:capacity, :integer, null: false)
      add(:current_enrollment, :integer, null: false, default: 0)
      add(:price_amount, :decimal, precision: 10, scale: 2, null: false)
      add(:price_currency, :string, null: false, size: 3, default: "USD")
      add(:price_unit, :string, null: false, size: 20)
      add(:has_discount, :boolean, null: false, default: false)
      add(:discount_amount, :decimal, precision: 10, scale: 2)
      add(:status, :string, null: false, size: 50, default: "draft")
      add(:is_prime_youth, :boolean, null: false, default: false)
      add(:featured, :boolean, null: false, default: false)
      add(:archived_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    # Indexes for programs table
    create(index(:programs, [:provider_id]))
    create(index(:programs, [:category]))
    create(index(:programs, [:status]))
    create(index(:programs, [:age_min, :age_max]))
    create(index(:programs, [:featured], where: "featured = true"))
    create(index(:programs, [:archived_at], where: "archived_at IS NULL"))

    # Full-text search index for programs
    execute(
      """
      CREATE INDEX programs_search_index ON programs
      USING GIN (to_tsvector('english', title || ' ' || description))
      """,
      "DROP INDEX IF EXISTS programs_search_index"
    )

    # Trigram index for fuzzy search
    execute(
      "CREATE INDEX programs_title_trgm_index ON programs USING GIN (title gin_trgm_ops)",
      "DROP INDEX IF EXISTS programs_title_trgm_index"
    )

    # Table: program_schedules
    create table(:program_schedules, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(:program_id, references(:programs, on_delete: :delete_all, type: :binary_id),
        null: false
      )

      add(:start_date, :date, null: false)
      add(:end_date, :date, null: false)
      add(:days_of_week, {:array, :string})
      add(:start_time, :time, null: false)
      add(:end_time, :time, null: false)
      add(:recurrence_pattern, :string, null: false, size: 20)
      add(:session_count, :integer)
      add(:session_duration, :integer)

      timestamps(type: :utc_datetime)
    end

    create(index(:program_schedules, [:program_id]))
    create(index(:program_schedules, [:start_date, :end_date]))

    # Table: locations
    create table(:locations, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(:program_id, references(:programs, on_delete: :delete_all, type: :binary_id),
        null: false
      )

      add(:name, :string, null: false, size: 200)
      add(:address_line1, :string, size: 200)
      add(:address_line2, :string, size: 200)
      add(:city, :string, size: 100)
      add(:state, :string, size: 100)
      add(:postal_code, :string, size: 20)
      add(:country, :string, size: 100)
      add(:is_virtual, :boolean, null: false, default: false)
      add(:virtual_link, :string, size: 255)
      add(:accessibility_notes, :text)

      timestamps(type: :utc_datetime)
    end

    create(index(:locations, [:program_id]))
    create(index(:locations, [:city, :state]))
    create(index(:locations, [:is_virtual]))

    # Add CHECK constraints for programs table
    create(
      constraint(:programs, :age_range_check,
        check: "age_min >= 0 AND age_min <= 18 AND age_max >= age_min AND age_max <= 18"
      )
    )

    create(constraint(:programs, :capacity_check, check: "capacity > 0"))

    create(
      constraint(:programs, :current_enrollment_check,
        check: "current_enrollment >= 0 AND current_enrollment <= capacity"
      )
    )

    create(constraint(:programs, :price_check, check: "price_amount >= 0"))

    create(
      constraint(:programs, :discount_check,
        check:
          "NOT has_discount OR (discount_amount IS NOT NULL AND discount_amount < price_amount)"
      )
    )

    # Add CHECK constraints for program_schedules table
    create(constraint(:program_schedules, :date_range_check, check: "end_date >= start_date"))
  end
end
