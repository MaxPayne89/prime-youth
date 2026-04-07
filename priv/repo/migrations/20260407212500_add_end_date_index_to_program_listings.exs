defmodule KlassHero.Repo.Migrations.AddEndDateIndexToProgramListings do
  use Ecto.Migration

  def change do
    create index(:program_listings, [:end_date])
  end
end
