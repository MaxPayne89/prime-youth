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
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema
  alias KlassHero.Provider.Domain.Models.IncidentReport
  alias KlassHero.Provider.Domain.ReadModels.IncidentReportSummary
  alias KlassHero.Repo

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
      assert saved.reporter_display_name == "Jane Doe"
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

  describe "get/1" do
    test "returns the report mapped to the domain entity" do
      provider = provider_profile_fixture()
      reporter = unconfirmed_user_fixture(intended_roles: [:provider])
      program = insert(:program_schema, provider_id: provider.id)

      report =
        build_report(%{
          provider_profile_id: provider.id,
          reporter_user_id: reporter.id,
          program_id: program.id
        })

      {:ok, %IncidentReport{} = saved} = IncidentReportRepository.create(report)

      assert {:ok, %IncidentReport{} = fetched} = IncidentReportRepository.get(saved.id)
      assert fetched.id == saved.id
      assert fetched.provider_profile_id == provider.id
      assert fetched.reporter_user_id == reporter.id
      assert fetched.program_id == program.id
      assert fetched.category == :safety_concern
      assert fetched.severity == :low
    end

    test "returns {:error, :not_found} when the report does not exist" do
      assert {:error, :not_found} = IncidentReportRepository.get(Ecto.UUID.generate())
    end
  end

  describe "list_for_program/2" do
    setup do
      provider = provider_profile_fixture()
      reporter = unconfirmed_user_fixture(intended_roles: [:provider])
      program = insert(:program_schema, provider_id: provider.id)
      %{provider: provider, reporter: reporter, program: program}
    end

    test "returns [] when no reports exist for the program", %{provider: p, program: pg} do
      assert IncidentReportRepository.list_for_program(p.id, pg.id) == []
    end

    test "returns program-direct reports as IncidentReportSummary", %{
      provider: p,
      reporter: r,
      program: pg
    } do
      report =
        build_report(%{
          provider_profile_id: p.id,
          reporter_user_id: r.id,
          program_id: pg.id,
          reporter_display_name: "Maria Schmidt"
        })

      {:ok, _saved} = IncidentReportRepository.create(report)

      assert [%IncidentReportSummary{} = summary] =
               IncidentReportRepository.list_for_program(p.id, pg.id)

      assert summary.id == report.id
      assert summary.program_id == pg.id
      assert summary.session_id == nil
      assert summary.reporter_display_name == "Maria Schmidt"
      assert summary.category == :safety_concern
    end

    test "returns session-linked reports for sessions belonging to the program", %{
      provider: p,
      reporter: r,
      program: pg
    } do
      session = insert(:program_session_schema, program_id: pg.id)
      put_provider_session_detail!(session.id, pg.id, p.id)

      report =
        build_report(%{
          provider_profile_id: p.id,
          reporter_user_id: r.id,
          program_id: nil,
          session_id: session.id
        })

      {:ok, _saved} = IncidentReportRepository.create(report)

      assert [%IncidentReportSummary{} = summary] =
               IncidentReportRepository.list_for_program(p.id, pg.id)

      assert summary.session_id == session.id
      assert summary.program_id == nil
    end

    test "excludes reports for a different provider's program", %{
      provider: p,
      reporter: r,
      program: pg
    } do
      other_provider = provider_profile_fixture()

      report =
        build_report(%{
          provider_profile_id: other_provider.id,
          reporter_user_id: r.id,
          program_id: pg.id
        })

      {:ok, _saved} = IncidentReportRepository.create(report)

      assert IncidentReportRepository.list_for_program(p.id, pg.id) == []
    end

    test "excludes session-linked reports for sessions of a different program", %{
      provider: p,
      reporter: r,
      program: pg
    } do
      other_program = insert(:program_schema, provider_id: p.id)
      other_session = insert(:program_session_schema, program_id: other_program.id)
      put_provider_session_detail!(other_session.id, other_program.id, p.id)

      report =
        build_report(%{
          provider_profile_id: p.id,
          reporter_user_id: r.id,
          program_id: nil,
          session_id: other_session.id
        })

      {:ok, _saved} = IncidentReportRepository.create(report)

      assert IncidentReportRepository.list_for_program(p.id, pg.id) == []
    end

    test "orders by occurred_at descending", %{
      provider: p,
      reporter: r,
      program: pg
    } do
      older =
        build_report(%{
          provider_profile_id: p.id,
          reporter_user_id: r.id,
          program_id: pg.id,
          occurred_at: ~U[2026-04-10 09:00:00Z]
        })

      newer =
        build_report(%{
          provider_profile_id: p.id,
          reporter_user_id: r.id,
          program_id: pg.id,
          occurred_at: ~U[2026-04-22 09:00:00Z]
        })

      {:ok, _} = IncidentReportRepository.create(older)
      {:ok, _} = IncidentReportRepository.create(newer)

      assert [first, second] = IncidentReportRepository.list_for_program(p.id, pg.id)
      assert first.id == newer.id
      assert second.id == older.id
    end
  end

  defp put_provider_session_detail!(session_id, program_id, provider_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.insert!(%ProviderSessionDetailSchema{
      session_id: session_id,
      program_id: program_id,
      program_title: "Test Program",
      provider_id: provider_id,
      session_date: ~D[2026-04-21],
      start_time: ~T[09:00:00],
      end_time: ~T[12:00:00],
      status: :scheduled,
      checked_in_count: 0,
      total_count: 0,
      inserted_at: now,
      updated_at: now
    })
  end

  defp build_report(attrs) do
    defaults = %{
      id: Ecto.UUID.generate(),
      category: :safety_concern,
      severity: :low,
      description: "Something happened during drop-off this morning.",
      occurred_at: ~U[2026-04-20 09:00:00Z],
      reporter_display_name: "Jane Doe"
    }

    {:ok, report} = IncidentReport.new(Map.merge(defaults, attrs))
    report
  end
end
