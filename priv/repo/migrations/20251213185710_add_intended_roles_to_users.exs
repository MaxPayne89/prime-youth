defmodule PrimeYouth.Repo.Migrations.AddIntendedRolesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :intended_roles, {:array, :string}, default: []
    end
  end
end
