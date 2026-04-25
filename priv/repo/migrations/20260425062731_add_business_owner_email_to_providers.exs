defmodule KlassHero.Repo.Migrations.AddBusinessOwnerEmailToProviders do
  use Ecto.Migration

  def up do
    alter table(:providers) do
      add :business_owner_email, :string
    end

    flush()

    execute(
      "UPDATE providers SET business_owner_email = users.email FROM users WHERE providers.identity_id = users.id"
    )
  end

  def down do
    alter table(:providers) do
      remove :business_owner_email
    end
  end
end
