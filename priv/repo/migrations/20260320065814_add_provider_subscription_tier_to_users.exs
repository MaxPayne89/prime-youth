defmodule KlassHero.Repo.Migrations.AddProviderSubscriptionTierToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :provider_subscription_tier, :string
    end
  end
end
