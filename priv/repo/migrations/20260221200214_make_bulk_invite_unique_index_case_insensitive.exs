defmodule KlassHero.Repo.Migrations.MakeBulkInviteUniqueIndexCaseInsensitive do
  use Ecto.Migration

  def up do
    drop unique_index(
           :bulk_enrollment_invites,
           [:program_id, :guardian_email, :child_first_name, :child_last_name],
           name: :bulk_invites_program_guardian_child_unique
         )

    # Trigger: Elixir duplicate detection lowercases names and emails
    # Why: DB unique index must match application behavior for consistency
    # Outcome: case-insensitive uniqueness at both application and DB level
    execute """
    CREATE UNIQUE INDEX bulk_invites_program_guardian_child_unique
    ON bulk_enrollment_invites (
      program_id,
      LOWER(guardian_email),
      LOWER(child_first_name),
      LOWER(child_last_name)
    )
    """
  end

  def down do
    execute "DROP INDEX bulk_invites_program_guardian_child_unique"

    create unique_index(
             :bulk_enrollment_invites,
             [:program_id, :guardian_email, :child_first_name, :child_last_name],
             name: :bulk_invites_program_guardian_child_unique
           )
  end
end
