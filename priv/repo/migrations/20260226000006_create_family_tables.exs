defmodule KlassHero.Repo.Migrations.CreateFamilyTables do
  use Ecto.Migration

  def up do
    create table(:children, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :first_name, :string, null: false, size: 100
      add :last_name, :string, null: false, size: 100
      add :date_of_birth, :date
      add :gender, :string, null: false, default: "not_specified"
      add :school_grade, :integer
      add :emergency_contact, :string, size: 255
      add :support_needs, :text
      add :allergies, :text
      add :school_name, :string, size: 255

      timestamps(type: :utc_datetime)
    end

    create constraint(:children, :valid_gender,
             check: "gender IN ('male', 'female', 'diverse', 'not_specified')"
           )

    create constraint(:children, :valid_school_grade,
             check: "school_grade IS NULL OR (school_grade >= 1 AND school_grade <= 13)"
           )

    create table(:children_guardians, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :child_id, references(:children, type: :binary_id, on_delete: :delete_all), null: false

      add :guardian_id, references(:parents, type: :binary_id, on_delete: :delete_all),
        null: false

      add :relationship, :string, null: false, default: "parent", size: 50
      add :is_primary, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:children_guardians, [:child_id, :guardian_id])
    create index(:children_guardians, [:guardian_id])

    create unique_index(:children_guardians, [:child_id],
             where: "is_primary = true",
             name: :children_guardians_one_primary_per_child
           )

    create constraint(:children_guardians, :valid_relationship,
             check: "relationship IN ('parent', 'guardian', 'other')"
           )

    create table(:consents, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :parent_id, references(:parents, type: :binary_id, on_delete: :restrict), null: false

      add :child_id, references(:children, type: :binary_id, on_delete: :restrict), null: false

      add :consent_type, :string, null: false, size: 100
      add :granted_at, :utc_datetime, null: false
      add :withdrawn_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:consents, [:child_id])
    create index(:consents, [:child_id, :consent_type])

    create unique_index(:consents, [:child_id, :consent_type],
             where: "withdrawn_at IS NULL",
             name: :consents_active_child_consent_type_index
           )
  end

  def down do
    drop table(:consents)
    drop table(:children_guardians)
    drop table(:children)
  end
end
