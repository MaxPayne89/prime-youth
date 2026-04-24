defmodule KlassHero.Repo.Migrations.CreateProviderProgramsProjection do
  use Ecto.Migration

  def change do
    create table(:provider_programs, primary_key: false) do
      add :program_id, :binary_id, primary_key: true
      add :provider_id, :binary_id, null: false
      add :name, :string, null: false
      add :status, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:provider_programs, [:provider_id])
  end
end
