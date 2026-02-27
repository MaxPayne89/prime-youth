defmodule KlassHero.Repo.Migrations.CreateConversationSummaries do
  use Ecto.Migration

  def up do
    create table(:conversation_summaries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :conversation_id, :binary_id, null: false
      add :user_id, :binary_id, null: false
      add :conversation_type, :string, null: false
      add :provider_id, :binary_id, null: false
      add :program_id, :binary_id
      add :subject, :string
      add :other_participant_name, :string
      add :participant_count, :integer, default: 0
      add :latest_message_content, :text
      add :latest_message_sender_id, :binary_id
      add :latest_message_at, :utc_datetime
      add :unread_count, :integer, default: 0, null: false
      add :last_read_at, :utc_datetime
      add :archived_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:conversation_summaries, [:conversation_id, :user_id])

    create index(:conversation_summaries, [:user_id, :archived_at, :latest_message_at],
             name: :conversation_summaries_inbox_idx
           )

    create index(:conversation_summaries, [:conversation_id])

    execute """
    CREATE INDEX conversation_summaries_unread_idx
    ON conversation_summaries (user_id)
    WHERE archived_at IS NULL
    """
  end

  def down do
    drop table(:conversation_summaries)
  end
end
