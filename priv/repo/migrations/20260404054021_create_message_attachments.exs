defmodule KlassHero.Repo.Migrations.CreateMessageAttachments do
  use Ecto.Migration

  def change do
    create table(:message_attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")

      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all),
        null: false

      add :file_url, :text, null: false
      add :storage_path, :string, size: 500, null: false
      add :original_filename, :string, size: 255, null: false
      add :content_type, :string, size: 100, null: false
      add :file_size_bytes, :bigint, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:message_attachments, [:message_id])
  end
end
