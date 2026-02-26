defmodule KlassHero.Repo.Migrations.CreateProviderResources do
  use Ecto.Migration

  def up do
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
      add :tags, {:array, :string}, null: false, default: []
      add :qualifications, {:array, :string}, null: false, default: []
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:staff_members, [:provider_id])

    create table(:verification_documents, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :provider_id, references(:providers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :document_type, :string, null: false
      add :file_url, :string, null: false
      add :original_filename, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :rejection_reason, :string
      add :reviewed_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :reviewed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:verification_documents, [:provider_id])
    create index(:verification_documents, [:status])
  end

  def down do
    drop table(:verification_documents)
    drop table(:staff_members)
  end
end
