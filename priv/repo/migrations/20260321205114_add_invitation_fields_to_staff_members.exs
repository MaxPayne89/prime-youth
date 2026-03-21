defmodule KlassHero.Repo.Migrations.AddInvitationFieldsToStaffMembers do
  use Ecto.Migration

  def change do
    alter table(:staff_members) do
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :invitation_status, :string
      add :invitation_token_hash, :binary
      add :invitation_sent_at, :utc_datetime_usec
    end

    create index(:staff_members, [:user_id])
    create index(:staff_members, [:invitation_token_hash], unique: true)
    create index(:staff_members, [:invitation_status])
  end
end
