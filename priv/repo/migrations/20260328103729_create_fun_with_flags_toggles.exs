defmodule KlassHero.Repo.Migrations.CreateFunWithFlagsToggles do
  use Ecto.Migration

  def change do
    create table(:fun_with_flags_toggles) do
      add :flag_name, :string, null: false
      add :gate_type, :string, null: false
      add :target, :string, null: false, default: ""
      add :enabled, :boolean, null: false
    end

    create index(:fun_with_flags_toggles, [:flag_name])

    create unique_index(:fun_with_flags_toggles, [:flag_name, :gate_type, :target],
             name: :fwf_flag_name_gate_target
           )
  end
end
