defmodule KlassHero.Repo.Migrations.AddSystemNotesToConversationSummaries do
  use Ecto.Migration

  def change do
    alter table(:conversation_summaries) do
      add :system_notes, :map, null: false, default: %{}
    end

    # Trigger: system note dedup queries use the ? (key-existence) operator
    # Why: jsonb_ops (default) supports ?, ?|, ?&, @> — jsonb_path_ops does not
    # Outcome: O(1) key lookup via GIN index regardless of table size
    create index(:conversation_summaries, [:system_notes], using: "gin")
  end
end
