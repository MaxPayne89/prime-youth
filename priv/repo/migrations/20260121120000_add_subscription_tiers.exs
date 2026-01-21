defmodule KlassHero.Repo.Migrations.AddSubscriptionTiers do
  use Ecto.Migration

  def change do
    alter table(:parents) do
      add :subscription_tier, :string, null: false, default: "explorer"
    end

    alter table(:providers) do
      add :subscription_tier, :string, null: false, default: "starter"
    end

    create index(:parents, [:subscription_tier])
    create index(:providers, [:subscription_tier])
  end
end
