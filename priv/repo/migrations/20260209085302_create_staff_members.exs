defmodule KlassHero.Repo.Migrations.CreateStaffMembers do
  use Ecto.Migration

  def change do
    create table(:staff_members, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :provider_id, references(:providers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :first_name, :string, null: false, size: 100
      add :last_name, :string, null: false, size: 100
      add :role, :string, size: 100
      add :email, :string, size: 255
      add :bio, :text
      add :headshot_url, :string
      add :tags, {:array, :string}, default: [], null: false
      add :qualifications, {:array, :string}, default: [], null: false
      add :active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:staff_members, [:provider_id])
  end
end
