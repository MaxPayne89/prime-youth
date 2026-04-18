defmodule KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionDetailsBootstrapTest do
  use KlassHero.DataCase, async: false

  import KlassHero.Factory

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProgramStaffAssignmentSchema
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderSessionDetailSchema
  alias KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionDetails
  alias KlassHero.Repo

  @tag :bootstrap
  test "bootstrap projects every existing session from write tables" do
    # Trigger: seed the write tables directly (no integration events emitted).
    # Why: exercises bootstrap's ability to self-heal the read table from the
    #      authoritative write tables — this is what rebuild/0 is for after
    #      seeds (which bypass the event bus).
    # Outcome: rebuild/0 projects every existing session row; the assertion
    #          verifies field resolution (program title, provider_id, status).
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id, title: "Judo")

    session_schema =
      insert(:program_session_schema,
        program_id: program.id,
        session_date: ~D[2026-05-01],
        start_time: ~T[15:00:00],
        end_time: ~T[16:00:00],
        status: "scheduled"
      )

    start_supervised!({ProviderSessionDetails, name: :bootstrap_test})
    :ok = ProviderSessionDetails.rebuild(:bootstrap_test)

    row = Repo.get(ProviderSessionDetailSchema, session_schema.id)

    assert row != nil
    assert row.program_title == "Judo"
    assert row.provider_id == provider.id
    assert row.status == :scheduled
    assert row.session_date == ~D[2026-05-01]
    assert row.start_time == ~T[15:00:00]
    assert row.end_time == ~T[16:00:00]
    assert row.checked_in_count == 0
    assert row.total_count == 0
  end

  @tag :bootstrap
  test "bootstrap resolves current_assigned_staff_id/name from active assignment" do
    # Trigger: program has an active (unassigned_at IS NULL) staff assignment
    # Why: bootstrap must join program_staff_assignments + staff_members and
    #      concatenate first/last name the same way the event handlers do.
    # Outcome: row carries the staff id and "First Last" display name.
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

    session_schema =
      insert(:program_session_schema,
        program_id: program.id,
        session_date: ~D[2026-06-01],
        start_time: ~T[10:00:00],
        end_time: ~T[11:00:00],
        status: "scheduled"
      )

    start_supervised!({ProviderSessionDetails, name: :bootstrap_test_staff})
    :ok = ProviderSessionDetails.rebuild(:bootstrap_test_staff)

    row = Repo.get(ProviderSessionDetailSchema, session_schema.id)

    assert row != nil
    assert row.current_assigned_staff_id == staff.id
    assert row.current_assigned_staff_name == "Ada Lovelace"
  end
end
