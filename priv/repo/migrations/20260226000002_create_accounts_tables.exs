defmodule KlassHero.Repo.Migrations.CreateAccountsTables do
  use Ecto.Migration

  def up do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :hashed_password, :string
      add :confirmed_at, :utc_datetime
      add :locale, :string, default: "en"
      add :name, :string, null: false, default: "User"
      add :avatar, :string
      add :intended_roles, {:array, :string}, default: []
      add :is_admin, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create index(:users, [:is_admin], where: "is_admin = true")

    create table(:users_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end

  def down do
    drop table(:users_tokens)
    drop table(:users)
  end
end
