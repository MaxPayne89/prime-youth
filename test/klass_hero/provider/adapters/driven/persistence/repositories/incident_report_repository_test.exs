defmodule KlassHero.Provider.Adapters.Driven.Persistence.Repositories.IncidentReportRepositoryTest do
  @moduledoc """
  Tests for the IncidentReportRepository adapter.

  Follows TDD approach: tests written first, then implementation.
  """

  use KlassHero.DataCase, async: true

  import KlassHero.AccountsFixtures
  import KlassHero.Factory
  import KlassHero.ProviderFixtures

  alias KlassHero.Provider.Adapters.Driven.Persistence.Repositories.IncidentReportRepository
  alias KlassHero.Provider.Domain.Models.IncidentReport

  describe "create/1" do
    test "persists a program-scoped report and returns the domain entity" do
      provider = provider_profile_fixture()
      reporter = unconfirmed_user_fixture(intended_roles: [:provider])
      program = insert(:program_schema, provider_id: provider.id)

      report =
        build_report(%{
          provider_profile_id: provider.id,
          reporter_user_id: reporter.id,
          program_id: program.id
        })

      assert {:ok, %IncidentReport{} = saved} = IncidentReportRepository.create(report)
      assert saved.id == report.id
      assert saved.provider_profile_id == provider.id
      assert saved.reporter_user_id == reporter.id
      assert saved.program_id == program.id
      assert saved.session_id == nil
      assert saved.category == :safety_concern
      assert saved.severity == :low
      assert saved.description == "Something happened during drop-off this morning."
      assert saved.occurred_at == ~U[2026-04-20 09:00:00Z]
      assert %DateTime{} = saved.inserted_at
      assert %DateTime{} = saved.updated_at
    end

    test "returns changeset error when provider FK is invalid" do
      reporter = unconfirmed_user_fixture(intended_roles: [:provider])
      # Use a real program so only the provider FK is bogus — this guarantees
      # the provider_id FK violation is the sole cause of the changeset error.
      provider = provider_profile_fixture()
      program = insert(:program_schema, provider_id: provider.id)

      report =
        build_report(%{
          provider_profile_id: Ecto.UUID.generate(),
          reporter_user_id: reporter.id,
          program_id: program.id
        })

      assert {:error, %Ecto.Changeset{valid?: false} = cs} =
               IncidentReportRepository.create(report)

      assert {"does not exist", _} = cs.errors[:provider_id]
    end
  end

  defp build_report(attrs) do
    defaults = %{
      id: Ecto.UUID.generate(),
      category: :safety_concern,
      severity: :low,
      description: "Something happened during drop-off this morning.",
      occurred_at: ~U[2026-04-20 09:00:00Z]
    }

    {:ok, report} = IncidentReport.new(Map.merge(defaults, attrs))
    report
  end
end
