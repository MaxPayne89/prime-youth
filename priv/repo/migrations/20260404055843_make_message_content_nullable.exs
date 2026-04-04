defmodule KlassHero.Repo.Migrations.MakeMessageContentNullable do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      modify :content, :text, null: true, from: {:text, null: false}
    end
  end
end
