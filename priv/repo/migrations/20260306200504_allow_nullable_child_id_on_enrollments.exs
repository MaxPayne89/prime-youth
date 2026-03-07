defmodule KlassHero.Repo.Migrations.AllowNullableChildIdOnEnrollments do
  use Ecto.Migration

  def change do
    # Trigger: child deletion needs to nullify enrollment.child_id
    # Why: RESTRICT FK blocks child deletion while enrollment rows reference child_id;
    #      nilify_all lets PostgreSQL auto-nullify on child delete
    # Outcome: enrollment rows persist (audit trail) with child_id set to nil
    alter table(:enrollments) do
      modify :child_id, references(:children, type: :binary_id, on_delete: :nilify_all),
        null: true,
        from: {references(:children, type: :binary_id, on_delete: :restrict), null: false}
    end
  end
end
