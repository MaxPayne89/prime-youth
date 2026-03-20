defmodule KlassHero.Repo.Migrations.CreateInboundEmails do
  use Ecto.Migration

  def change do
    create table(:inbound_emails, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :resend_id, :string, null: false
      add :from_address, :string, null: false
      add :from_name, :string
      add :to_addresses, {:array, :string}, null: false, default: []
      add :cc_addresses, {:array, :string}, default: []
      add :subject, :string, null: false
      add :body_html, :text
      add :body_text, :text
      add :headers, {:array, :map}, null: false, default: []
      add :status, :string, null: false, default: "unread"
      add :read_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :read_at, :utc_datetime_usec
      add :received_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:inbound_emails, [:resend_id])
    create index(:inbound_emails, [:status])
    create index(:inbound_emails, [:received_at])
    create index(:inbound_emails, [:read_by_id])
  end
end
