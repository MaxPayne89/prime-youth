defmodule KlassHero.Repo.Migrations.AddEnrolledChildNamesToConversationSummaries do
  use Ecto.Migration

  def change do
    alter table(:conversation_summaries) do
      add :enrolled_child_names, {:array, :string}, default: []
    end
  end
end
