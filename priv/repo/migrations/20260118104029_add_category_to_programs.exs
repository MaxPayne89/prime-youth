defmodule KlassHero.Repo.Migrations.AddCategoryToPrograms do
  use Ecto.Migration

  def change do
    alter table(:programs) do
      add :category, :string, null: false, default: "education", size: 50
    end

    # Index on category for efficient filtering
    create index(:programs, [:category])

    # Composite index for paginated category queries (category + inserted_at + id)
    create index(:programs, [:category, :inserted_at, :id])
  end
end
