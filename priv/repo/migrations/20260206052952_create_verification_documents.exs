defmodule KlassHero.Repo.Migrations.CreateVerificationDocuments do
  use Ecto.Migration

  def change do
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
    create index(:verification_documents, [:reviewed_by_id])
  end
end
