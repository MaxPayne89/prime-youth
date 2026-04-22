defmodule KlassHero.Repo.Migrations.AddPayRateToStaffMembers do
  use Ecto.Migration

  def change do
    alter table(:staff_members) do
      add :rate_type, :string
      add :rate_amount, :decimal, precision: 10, scale: 2
      add :rate_currency, :string, size: 3
    end

    create constraint(:staff_members, :pay_rate_all_or_none,
             check: """
             (rate_type IS NULL AND rate_amount IS NULL AND rate_currency IS NULL)
             OR
             (rate_type IS NOT NULL AND rate_amount IS NOT NULL AND rate_currency IS NOT NULL)
             """
           )
  end
end
