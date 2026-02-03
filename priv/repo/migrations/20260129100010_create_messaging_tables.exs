defmodule KlassHero.Repo.Migrations.CreateMessagingTables do
  use Ecto.Migration

  def change do
    # Conversations table
    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false

      add :provider_id, references(:providers, type: :binary_id, on_delete: :restrict),
        null: false

      add :program_id, references(:programs, type: :binary_id, on_delete: :restrict)
      add :subject, :string
      add :archived_at, :utc_datetime
      add :retention_until, :utc_datetime
      add :lock_version, :integer, default: 1, null: false

      timestamps()
    end

    create index(:conversations, [:provider_id])
    create index(:conversations, [:program_id])
    create index(:conversations, [:type])
    create index(:conversations, [:archived_at])

    # Partial unique index: one active broadcast per program
    create unique_index(:conversations, [:program_id],
             where: "type = 'program_broadcast' AND archived_at IS NULL",
             name: :conversations_active_broadcast_per_program
           )

    # Conversation participants table
    create table(:conversation_participants, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :last_read_at, :utc_datetime
      add :joined_at, :utc_datetime, null: false
      add :left_at, :utc_datetime

      timestamps()
    end

    create index(:conversation_participants, [:conversation_id])
    create index(:conversation_participants, [:user_id])
    create unique_index(:conversation_participants, [:conversation_id, :user_id])

    # Messages table
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :sender_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :content, :text, null: false
      add :message_type, :string, default: "text", null: false
      add :deleted_at, :utc_datetime

      timestamps()
    end

    create index(:messages, [:conversation_id, :inserted_at])
    create index(:messages, [:sender_id])
    create index(:messages, [:deleted_at])
  end
end
