defmodule KlassHero.Provider.Application.Commands.Incident.SubmitIncidentReportTest do
  use KlassHero.DataCase, async: false

  import Ecto.Query
  import KlassHero.AccountsFixtures, only: [unconfirmed_user_fixture: 1]
  import KlassHero.EmailTestHelper
  import KlassHero.Factory
  import KlassHero.ProviderFixtures, only: [provider_program_projection_fixture: 1]
  import Swoosh.TestAssertions

  alias Ecto.Adapters.SQL.Sandbox
  alias KlassHero.Accounts.User
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.IncidentReportSchema
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema
  alias KlassHero.Provider.Adapters.Driving.Events.IncidentReportedHandler
  alias KlassHero.Provider.Application.Commands.Incident.SubmitIncidentReport
  alias KlassHero.Repo
  alias KlassHero.Shared.Adapters.Driven.Events.PubSubIntegrationEventPublisher
  alias KlassHero.Shared.Adapters.Driven.Storage.StubStorageAdapter
  alias KlassHero.Shared.DomainEventBus

  setup do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id)
    user = unconfirmed_user_fixture(%{})

    provider_program_projection_fixture(
      provider_id: provider.id,
      program_id: program.id,
      name: "Art Club"
    )

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
      reporter_display_name: user.name || "Test Reporter",
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

    test "persists reporter_display_name as a snapshot", %{provider: p, program_id: pg, user: u} do
      params = p |> base_params(pg, u) |> Map.put(:reporter_display_name, "Maria Schmidt")

      assert {:ok, report} = SubmitIncidentReport.execute(params)
      assert report.reporter_display_name == "Maria Schmidt"

      stored = Repo.get(IncidentReportSchema, report.id)
      assert stored.reporter_display_name == "Maria Schmidt"
    end

    test "rejects when reporter_display_name is blank", %{provider: p, program_id: pg, user: u} do
      params = p |> base_params(pg, u) |> Map.put(:reporter_display_name, "   ")

      assert {:error, errors} = SubmitIncidentReport.execute(params)
      assert errors[:reporter_display_name] =~ "required"
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

  describe "execute/1 — incident email pipeline (end-to-end)" do
    # Trigger: tests need PubSub-driven CriticalEventDispatcher → handler → Oban inline
    # Why: the default test publisher only collects events; it does not broadcast,
    #      so the IncidentReportedHandler subscriber would never wake up
    # Outcome: swap to real PubSub, grant the subscriber sandbox access, route Swoosh
    #          mail back to the test pid even when Mailer.deliver runs in another process
    setup do
      flush_emails()

      original_publisher = Application.get_env(:klass_hero, :integration_event_publisher)

      Application.put_env(:klass_hero, :integration_event_publisher,
        module: PubSubIntegrationEventPublisher,
        pubsub: KlassHero.PubSub
      )

      original_swoosh_pid = Application.get_env(:swoosh, :shared_test_process)
      Application.put_env(:swoosh, :shared_test_process, self())

      case Process.whereis(IncidentReportedHandler) do
        nil -> :ok
        pid -> Sandbox.allow(KlassHero.Repo, self(), pid)
      end

      on_exit(fn ->
        Application.put_env(:klass_hero, :integration_event_publisher, original_publisher)

        if original_swoosh_pid do
          Application.put_env(:swoosh, :shared_test_process, original_swoosh_pid)
        else
          Application.delete_env(:swoosh, :shared_test_process)
        end
      end)

      :ok
    end

    test "delivers an email to the business owner when reporter is not the owner", %{
      provider: provider,
      program_id: program_id,
      user: reporter
    } do
      # Backfill the email column on the existing provider row so the use case can
      # resolve a recipient — production rows are populated by ProviderEventHandler
      # off the :user_registered integration event payload.
      provider
      |> Ecto.Changeset.change(%{business_owner_email: "owner@example.com"})
      |> Repo.update!()

      params = base_params(provider, program_id, reporter)

      assert {:ok, _report} = SubmitIncidentReport.execute(params)

      assert_email_sent(fn email ->
        email.to == [{provider.business_name, "owner@example.com"}] and
          email.subject =~ "Art Club"
      end)
    end

    test "skips the email when the reporter is the provider owner (self-report)", %{
      provider: provider,
      program_id: program_id
    } do
      owner = Repo.get!(User, provider.identity_id)

      provider
      |> Ecto.Changeset.change(%{business_owner_email: "owner@example.com"})
      |> Repo.update!()

      params = base_params(provider, program_id, owner)

      assert {:ok, _report} = SubmitIncidentReport.execute(params)

      assert_no_email_sent()
    end
  end
end
