defmodule KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionDetailsTest do
  use KlassHero.DataCase, async: false

  import Ecto.Query
  import ExUnit.CaptureLog
  import KlassHero.Factory

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProgramStaffAssignmentSchema
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema
  alias KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionDetails
  alias KlassHero.Repo
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  @test_server_name :test_provider_session_details

  setup do
    start_supervised!({ProviderSessionDetails, name: @test_server_name})
    # Synchronize: ensure bootstrap has completed before running the test body
    _ = :sys.get_state(@test_server_name)
    :ok
  end

  test "starts and responds to a ping call" do
    assert Process.whereis(@test_server_name) |> is_pid()
  end

  describe "session_created" do
    test "inserts a row with defaults, resolving program_title and provider_id" do
      # Trigger: programs FK on provider_id requires a real provider row
      # Why: the handler reads programs to resolve program_title/provider_id
      # Outcome: factory creates a provider + user that satisfies FK constraints
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id, title: "Judo")
      session_id = Ecto.UUID.generate()

      event =
        IntegrationEvent.new(
          :session_created,
          :participation,
          :session,
          session_id,
          %{
            session_id: session_id,
            program_id: program.id,
            session_date: ~D[2026-05-01],
            start_time: ~T[15:00:00],
            end_time: ~T[16:00:00]
          }
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:participation:session_created",
        {:integration_event, event}
      )

      # Synchronize: ensure GenServer has processed the broadcast
      _ = :sys.get_state(@test_server_name)

      row = Repo.get(ProviderSessionDetailSchema, session_id)

      assert row != nil
      assert row.program_id == program.id
      assert row.program_title == "Judo"
      assert row.provider_id == provider.id
      assert row.session_date == ~D[2026-05-01]
      assert row.start_time == ~T[15:00:00]
      assert row.end_time == ~T[16:00:00]
      assert row.status == :scheduled
      assert row.checked_in_count == 0
      assert row.total_count == 0
      assert row.current_assigned_staff_id == nil
      assert row.current_assigned_staff_name == nil
    end

    test "resolves current_assigned_staff_id/name from active program_staff_assignments row" do
      # Trigger: handler reads program_staff_assignments joined with staff_members
      # Why: exercise the happy-path active-staff resolution (WHERE unassigned_at IS NULL)
      # Outcome: row carries the seeded staff id + concatenated "First Last" name
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id, title: "Karate")

      staff =
        insert(:staff_member_schema,
          provider_id: provider.id,
          first_name: "Ada",
          last_name: "Lovelace"
        )

      {:ok, _assignment} =
        %ProgramStaffAssignmentSchema{}
        |> ProgramStaffAssignmentSchema.create_changeset(%{
          provider_id: provider.id,
          staff_member_id: staff.id,
          program_id: program.id,
          assigned_at: DateTime.utc_now()
        })
        |> Repo.insert()

      session_id = Ecto.UUID.generate()

      event =
        IntegrationEvent.new(
          :session_created,
          :participation,
          :session,
          session_id,
          %{
            session_id: session_id,
            program_id: program.id,
            session_date: ~D[2026-05-02],
            start_time: ~T[10:00:00],
            end_time: ~T[11:00:00]
          }
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:participation:session_created",
        {:integration_event, event}
      )

      # Synchronize: ensure GenServer has processed the broadcast
      _ = :sys.get_state(@test_server_name)

      row = Repo.get(ProviderSessionDetailSchema, session_id)

      assert row != nil
      assert row.current_assigned_staff_id == staff.id
      assert row.current_assigned_staff_name == "Ada Lovelace"
    end

    test "duplicate delivery preserves evolved state written by other handlers" do
      # Trigger: session_created is replayed (at-least-once delivery) after other
      #          handlers (session_started/completed, roster_seeded, child_checked_in,
      #          and a future cover-staff handler) have mutated the row
      # Why: spec requires session_created to be a no-op on duplicate delivery —
      #      it must NOT stomp evolved state owned by other handlers
      # Outcome: after a second broadcast, status/checked_in_count/total_count and
      #          cover_staff_* fields retain the evolved values
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id, title: "Aikido")
      session_id = Ecto.UUID.generate()

      event =
        IntegrationEvent.new(
          :session_created,
          :participation,
          :session,
          session_id,
          %{
            session_id: session_id,
            program_id: program.id,
            session_date: ~D[2026-05-03],
            start_time: ~T[09:00:00],
            end_time: ~T[10:00:00]
          }
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:participation:session_created",
        {:integration_event, event}
      )

      # Synchronize: ensure GenServer has processed the first broadcast
      _ = :sys.get_state(@test_server_name)

      # Simulate evolved state written by other handlers between deliveries
      cover_staff_id = Ecto.UUID.generate()

      Repo.update_all(
        from(d in ProviderSessionDetailSchema, where: d.session_id == ^session_id),
        set: [
          status: :in_progress,
          checked_in_count: 5,
          total_count: 10,
          cover_staff_id: cover_staff_id,
          cover_staff_name: "Cover Person"
        ]
      )

      # Replay the same event (at-least-once delivery)
      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:participation:session_created",
        {:integration_event, event}
      )

      # Synchronize: ensure GenServer has processed the replay
      _ = :sys.get_state(@test_server_name)

      row = Repo.get(ProviderSessionDetailSchema, session_id)

      assert row != nil
      assert row.status == :in_progress
      assert row.checked_in_count == 5
      assert row.total_count == 10
      assert row.cover_staff_id == cover_staff_id
      assert row.cover_staff_name == "Cover Person"
    end
  end

  describe "status transitions" do
    setup :insert_seed_session

    test "session_started sets status=:in_progress", %{session_id: session_id} do
      broadcast(:session_started, session_id, %{session_id: session_id, program_id: "prog"})

      # Synchronize: ensure GenServer has processed the broadcast
      _ = :sys.get_state(@test_server_name)

      assert %{status: :in_progress} = reload(session_id)
    end

    test "session_completed sets status=:completed", %{session_id: session_id} do
      broadcast(:session_completed, session_id, %{
        session_id: session_id,
        program_id: "prog",
        provider_id: "prv",
        program_title: "Judo"
      })

      # Synchronize: ensure GenServer has processed the broadcast
      _ = :sys.get_state(@test_server_name)

      assert %{status: :completed} = reload(session_id)
    end

    test "session_cancelled sets status=:cancelled", %{session_id: session_id} do
      broadcast(:session_cancelled, session_id, %{session_id: session_id, program_id: "prog"})

      # Synchronize: ensure GenServer has processed the broadcast
      _ = :sys.get_state(@test_server_name)

      assert %{status: :cancelled} = reload(session_id)
    end

    test "logs a warning when the session row is missing" do
      unknown_id = Ecto.UUID.generate()

      log =
        capture_log(fn ->
          broadcast(:session_started, unknown_id, %{session_id: unknown_id, program_id: "prog"})
          _ = :sys.get_state(@test_server_name)
        end)

      assert log =~ "status transition skipped"
      assert log =~ unknown_id
    end
  end

  describe "roster_seeded" do
    setup :insert_seed_session

    test "sets total_count from seeded_count", %{session_id: session_id} do
      broadcast(:roster_seeded, session_id, %{
        session_id: session_id,
        program_id: "prog",
        seeded_count: 7
      })

      # Synchronize: ensure GenServer has processed the broadcast
      _ = :sys.get_state(@test_server_name)

      assert %{total_count: 7} = reload(session_id)
    end

    test "logs a warning when the session row is missing" do
      unknown_id = Ecto.UUID.generate()

      log =
        capture_log(fn ->
          broadcast(:roster_seeded, unknown_id, %{
            session_id: unknown_id,
            program_id: "prog",
            seeded_count: 3
          })

          _ = :sys.get_state(@test_server_name)
        end)

      assert log =~ "roster_seeded skipped"
      assert log =~ unknown_id
    end
  end

  describe "attendance counters" do
    setup :insert_seed_session

    test "child_checked_in increments checked_in_count", %{session_id: session_id} do
      broadcast(:child_checked_in, "rec-1", %{
        record_id: "rec-1",
        session_id: session_id,
        child_id: "c-1"
      })

      # Synchronize: ensure GenServer has processed the broadcast
      _ = :sys.get_state(@test_server_name)

      assert %{checked_in_count: 1} = reload(session_id)
    end

    test "two check-ins increment to 2", %{session_id: session_id} do
      broadcast(:child_checked_in, "rec-1", %{
        record_id: "rec-1",
        session_id: session_id,
        child_id: "c-1"
      })

      broadcast(:child_checked_in, "rec-2", %{
        record_id: "rec-2",
        session_id: session_id,
        child_id: "c-2"
      })

      # Synchronize: ensure GenServer has processed both broadcasts
      _ = :sys.get_state(@test_server_name)

      assert %{checked_in_count: 2} = reload(session_id)
    end

    test "child_checked_out does not decrement", %{session_id: session_id} do
      broadcast(:child_checked_in, "rec-1", %{
        record_id: "rec-1",
        session_id: session_id,
        child_id: "c-1"
      })

      _ = :sys.get_state(@test_server_name)
      assert %{checked_in_count: 1} = reload(session_id)

      broadcast(:child_checked_out, "rec-1", %{
        record_id: "rec-1",
        session_id: session_id,
        child_id: "c-1"
      })

      _ = :sys.get_state(@test_server_name)
      assert %{checked_in_count: 1} = reload(session_id)
    end

    test "child_marked_absent does not change count", %{session_id: session_id} do
      broadcast(:child_marked_absent, "rec-1", %{
        record_id: "rec-1",
        session_id: session_id,
        child_id: "c-1"
      })

      _ = :sys.get_state(@test_server_name)

      assert %{checked_in_count: 0} = reload(session_id)
    end

    test "logs a warning when child_checked_in arrives for an unknown session" do
      unknown_id = Ecto.UUID.generate()

      log =
        capture_log(fn ->
          broadcast(:child_checked_in, "rec-ghost", %{
            record_id: "rec-ghost",
            session_id: unknown_id,
            child_id: "c-1"
          })

          _ = :sys.get_state(@test_server_name)
        end)

      assert log =~ "child_checked_in skipped"
      assert log =~ unknown_id
    end
  end

  defp broadcast(event_type, entity_id, payload) do
    event = IntegrationEvent.new(event_type, :participation, :session, entity_id, payload)

    Phoenix.PubSub.broadcast(
      KlassHero.PubSub,
      "integration:participation:#{event_type}",
      {:integration_event, event}
    )
  end

  defp reload(session_id) do
    Repo.get(ProviderSessionDetailSchema, session_id)
  end

  defp insert_seed_session(_ctx) do
    session_id = Ecto.UUID.generate()
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.insert_all(ProviderSessionDetailSchema, [
      %{
        session_id: session_id,
        program_id: Ecto.UUID.generate(),
        program_title: "X",
        provider_id: Ecto.UUID.generate(),
        session_date: ~D[2026-05-01],
        start_time: ~T[09:00:00],
        end_time: ~T[10:00:00],
        status: :scheduled,
        checked_in_count: 0,
        total_count: 0,
        inserted_at: now,
        updated_at: now
      }
    ])

    %{session_id: session_id}
  end
end
