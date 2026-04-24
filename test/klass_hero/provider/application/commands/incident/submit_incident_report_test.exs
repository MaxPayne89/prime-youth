defmodule KlassHero.Provider.Application.Commands.Incident.SubmitIncidentReportTest do
  use KlassHero.DataCase, async: false

  import Ecto.Query
  import KlassHero.AccountsFixtures, only: [unconfirmed_user_fixture: 1]
  import KlassHero.Factory

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.IncidentReportSchema
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProgramProjectionSchema
  alias KlassHero.Provider.Application.Commands.Incident.SubmitIncidentReport
  alias KlassHero.Repo
  alias KlassHero.Shared.DomainEventBus

  setup do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id)
    user = unconfirmed_user_fixture(%{})
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.insert!(%ProviderProgramProjectionSchema{
      program_id: program.id,
      provider_id: provider.id,
      name: "Art Club",
      status: "active",
      inserted_at: now,
      updated_at: now
    })

    test_pid = self()

    DomainEventBus.subscribe(KlassHero.Provider, :incident_reported, fn event ->
      send(test_pid, {:domain_event, event})
      :ok
    end)

    %{provider: provider, program_id: program.id, user: user}
  end

  defp base_params(provider, program_id, user) do
    %{
      provider_profile_id: provider.id,
      reporter_user_id: user.id,
      program_id: program_id,
      session_id: nil,
      category: :safety_concern,
      severity: :medium,
      description: "Someone was running in the hallway — no injury but worth flagging.",
      occurred_at: ~U[2026-04-21 15:00:00Z],
      file_binary: nil
    }
  end

  describe "execute/1 — program scope" do
    test "persists the report and emits an incident_reported domain event", %{
      provider: p,
      program_id: pg,
      user: u
    } do
      params = base_params(p, pg, u)

      assert {:ok, report} = SubmitIncidentReport.execute(params)
      assert Repo.get(IncidentReportSchema, report.id)

      assert_receive {:domain_event, event}, 500
      assert event.event_type == :incident_reported
      assert event.aggregate_id == report.id
      assert event.payload.program_id == pg
      assert event.payload.has_photo == false
    end

    test "fails when program_id does not belong to the provider", %{provider: p, user: u} do
      params = base_params(p, Ecto.UUID.generate(), u)

      assert {:error, errors} = SubmitIncidentReport.execute(params)
      assert errors[:program_id] == "does not belong to this provider"
      refute Repo.exists?(from r in IncidentReportSchema, select: r.id, limit: 1)
    end

    test "rejects invalid domain data without persistence (description too short)",
         %{provider: p, program_id: pg, user: u} do
      params = p |> base_params(pg, u) |> Map.put(:description, "short")

      assert {:error, errors} = SubmitIncidentReport.execute(params)
      assert errors[:description] =~ "at least 10"
      refute Repo.exists?(from r in IncidentReportSchema, select: r.id, limit: 1)
    end
  end
end
