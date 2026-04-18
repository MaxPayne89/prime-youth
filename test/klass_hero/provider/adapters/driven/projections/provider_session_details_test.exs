defmodule KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionDetailsTest do
  use KlassHero.DataCase, async: false

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
  end
end
