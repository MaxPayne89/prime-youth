defmodule KlassHero.Repo.Migrations.AddGenderAndGradeToChildren do
  use Ecto.Migration

  def change do
    alter table(:children) do
      add :gender, :string, default: "not_specified", null: false
      add :school_grade, :integer
    end

    create constraint(:children, :valid_gender,
             check: "gender IN ('male', 'female', 'diverse', 'not_specified')"
           )

    create constraint(:children, :valid_school_grade,
             check: "school_grade IS NULL OR (school_grade >= 1 AND school_grade <= 13)"
           )
  end
end
