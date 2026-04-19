defmodule KlassHero.Repo.Migrations.CreateMessagingEnrolledChildren do
  use Ecto.Migration

  def change do
    create table(:messaging_enrolled_children, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :parent_user_id, :binary_id, null: false
      add :program_id, :binary_id, null: false
      add :child_id, :binary_id, null: false
      add :child_first_name, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:messaging_enrolled_children, [:parent_user_id, :program_id, :child_id])
    create index(:messaging_enrolled_children, [:parent_user_id, :program_id])
    create index(:messaging_enrolled_children, [:child_id])
  end
end
