defmodule KlassHero.Provider.Application.Commands.Incident.SubmitIncidentReportTest do
  use KlassHero.DataCase, async: false

  import Ecto.Query
  import KlassHero.AccountsFixtures, only: [unconfirmed_user_fixture: 1]
  import KlassHero.Factory

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.IncidentReportSchema
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProgramProjectionSchema
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema
  alias KlassHero.Provider.Application.Commands.Incident.SubmitIncidentReport
  alias KlassHero.Repo
  alias KlassHero.Shared.Adapters.Driven.Storage.StubStorageAdapter
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

  describe "execute/1 — session scope" do
    test "persists the report and emits an incident_reported domain event", %{
      provider: p,
      program_id: pg,
      user: u
    } do
      session = insert(:program_session_schema, program_id: pg)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Repo.insert!(%ProviderSessionDetailSchema{
        session_id: session.id,
        program_id: pg,
        program_title: "Art Club",
        provider_id: p.id,
        session_date: ~D[2026-04-21],
        start_time: ~T[09:00:00],
        end_time: ~T[12:00:00],
        status: :scheduled,
        checked_in_count: 0,
        total_count: 0,
        inserted_at: now,
        updated_at: now
      })

      params =
        p
        |> base_params(nil, u)
        |> Map.put(:program_id, nil)
        |> Map.put(:session_id, session.id)

      assert {:ok, report} = SubmitIncidentReport.execute(params)

      assert_receive {:domain_event, event}, 500
      assert event.event_type == :incident_reported
      assert event.aggregate_id == report.id
      assert is_nil(event.payload.program_id)
      assert event.payload.session_id == session.id
      assert event.payload.has_photo == false
    end
  end

  describe "execute/1 — photo upload" do
    setup do
      {:ok, storage} = StubStorageAdapter.start_link(name: :"storage_#{System.unique_integer([:positive])}")
      %{storage: storage}
    end

    test "uploads photo and persists URL", %{
      provider: p,
      program_id: pg,
      user: u,
      storage: storage
    } do
      photo_binary = "fake-jpeg-bytes"

      params =
        p
        |> base_params(pg, u)
        |> Map.put(:file_binary, photo_binary)
        |> Map.put(:original_filename, "incident.jpg")
        |> Map.put(:content_type, "image/jpeg")
        |> Map.put(:storage_opts, adapter: StubStorageAdapter, agent: storage)

      assert {:ok, report} = SubmitIncidentReport.execute(params)
      assert report.photo_url =~ "incident-reports/providers/#{p.id}/"
      assert report.photo_url =~ "incident.jpg"
      assert report.original_filename == "incident.jpg"

      assert {:ok, ^photo_binary} =
               StubStorageAdapter.get_uploaded(:private, report.photo_url, agent: storage)

      assert_receive {:domain_event, event}, 500
      assert event.event_type == :incident_reported
      assert event.payload.has_photo == true
    end

    # Trigger: file_binary supplied without an original_filename (or with a blank one)
    # Why: validating filename presence AFTER upload leaves an orphan in private storage
    #      because the downstream domain model rejects the photo_url via validate_photo_pair/1
    # Outcome: short-circuit with an :original_filename validation error and never call the storage adapter
    test "rejects with missing-filename error and never uploads when filename is blank", %{
      provider: p,
      program_id: pg,
      user: u,
      storage: storage
    } do
      params =
        p
        |> base_params(pg, u)
        |> Map.put(:file_binary, "fake-bytes")
        |> Map.put(:original_filename, nil)
        |> Map.put(:storage_opts, adapter: StubStorageAdapter, agent: storage)

      assert {:error, errors} = SubmitIncidentReport.execute(params)
      assert errors[:original_filename] =~ "is required"

      # Storage stub agent should hold no entries — proves we never called upload/4
      assert Agent.get(storage, & &1) == %{}
    end
  end
end
