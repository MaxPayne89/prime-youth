defmodule KlassHero.Repo.Migrations.AddHasAttachmentsToConversationSummaries do
  use Ecto.Migration

  def change do
    alter table(:conversation_summaries) do
      add :has_attachments, :boolean, default: false, null: false
    end
  end
end
