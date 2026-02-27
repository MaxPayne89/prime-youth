defmodule KlassHero.Repo.Migrations.AddUnreadCountCheckConstraint do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE conversation_summaries ADD CONSTRAINT unread_count_non_negative CHECK (unread_count >= 0)"
  end

  def down do
    execute "ALTER TABLE conversation_summaries DROP CONSTRAINT unread_count_non_negative"
  end
end
