defmodule KlassHero.Repo.Migrations.AddEmailContentAndReplies do
  use Ecto.Migration

  def change do
    alter table(:inbound_emails) do
      add :message_id, :string
      add :content_status, :string, null: false, default: "pending"
    end

    # Trigger: existing emails already have body content from the old webhook flow
    # Why: default "pending" would show a loading spinner forever for them
    # Outcome: pre-existing emails with content get "fetched" status
    execute(
      "UPDATE inbound_emails SET content_status = 'fetched' WHERE body_html IS NOT NULL OR body_text IS NOT NULL",
      "UPDATE inbound_emails SET content_status = 'pending'"
    )

    create table(:email_replies, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :inbound_email_id,
          references(:inbound_emails, type: :binary_id, on_delete: :delete_all), null: false

      add :body, :text, null: false
      add :sent_by_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :status, :string, null: false, default: "sending"
      add :resend_message_id, :string
      add :sent_at, :utc_datetime_usec

      timestamps(type: :utc_datetime)
    end

    create index(:inbound_emails, [:content_status])
    create index(:email_replies, [:inbound_email_id])
    create index(:email_replies, [:sent_by_id])
    create index(:email_replies, [:status])
  end
end
