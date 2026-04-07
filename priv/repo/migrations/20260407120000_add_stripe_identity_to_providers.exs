defmodule KlassHero.Repo.Migrations.AddStripeIdentityToProviders do
  use Ecto.Migration

  def change do
    alter table(:providers) do
      add :stripe_identity_session_id, :string
      add :stripe_identity_status, :string, default: "not_started", null: false
    end
  end
end
