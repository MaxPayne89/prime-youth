defmodule KlassHero.Repo.Migrations.AddIsAdminToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_admin, :boolean, default: false, null: false
    end

    # Trigger: we need efficient lookup of admin users
    # Why: partial index only indexes rows where is_admin = true, keeping index small
    # Outcome: fast queries like "find all admins" or "check if user is admin"
    create index(:users, [:is_admin], where: "is_admin = true")
  end
end
