defmodule PrimeYouth.Participation.Application.UseCases.GetSessionWithRosterTest do
  @moduledoc """
  Integration tests for GetSessionWithRoster use case.

  Tests retrieving a session with its participation roster.
  """

  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Participation.Application.UseCases.GetSessionWithRoster
  alias PrimeYouth.Participation.Domain.Models.ParticipationRecord
  alias PrimeYouth.Participation.Domain.Models.ProgramSession

  describe "execute/1" do
    test "returns session with roster entries" do
      session_schema = insert(:program_session_schema)
      child1 = insert(:child_schema)
      child2 = insert(:child_schema)

      insert(:participation_record_schema,
        session_id: session_schema.id,
        child_id: child1.id,
        status: :registered
      )

      insert(:participation_record_schema,
        session_id: session_schema.id,
        child_id: child2.id,
        status: :checked_in,
        check_in_at: DateTime.utc_now(),
        check_in_by: Ecto.UUID.generate()
      )

      assert {:ok, result} = GetSessionWithRoster.execute(session_schema.id)
      assert %ProgramSession{} = result.session
      assert result.session.id == session_schema.id
      assert is_list(result.roster)
      assert length(result.roster) == 2

      assert Enum.all?(result.roster, fn entry -> match?(%ParticipationRecord{}, entry.record) end)
    end

    test "returns session with empty roster when no participation records" do
      session_schema = insert(:program_session_schema)

      assert {:ok, result} = GetSessionWithRoster.execute(session_schema.id)
      assert %ProgramSession{} = result.session
      assert result.roster == []
    end

    test "returns error when session not found" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = GetSessionWithRoster.execute(non_existent_id)
    end

    test "includes child name in roster entries" do
      session_schema = insert(:program_session_schema)
      child = insert(:child_schema)
      check_in_time = DateTime.utc_now()

      insert(:participation_record_schema,
        session_id: session_schema.id,
        child_id: child.id,
        status: :checked_in,
        check_in_at: check_in_time,
        check_in_by: Ecto.UUID.generate(),
        check_in_notes: "Arrived on time"
      )

      assert {:ok, result} = GetSessionWithRoster.execute(session_schema.id)
      assert [entry] = result.roster
      assert entry.record.child_id == child.id
      assert entry.record.status == :checked_in
      assert entry.record.check_in_notes == "Arrived on time"
      assert is_binary(entry.child_name)
    end

    test "only returns roster for specified session" do
      session1 = insert(:program_session_schema)
      session2 = insert(:program_session_schema)
      child = insert(:child_schema)

      insert(:participation_record_schema,
        session_id: session1.id,
        child_id: child.id,
        status: :registered
      )

      insert(:participation_record_schema,
        session_id: session2.id,
        child_id: child.id,
        status: :checked_in,
        check_in_at: DateTime.utc_now(),
        check_in_by: Ecto.UUID.generate()
      )

      assert {:ok, result} = GetSessionWithRoster.execute(session1.id)
      assert length(result.roster) == 1
      assert hd(result.roster).record.session_id == session1.id
    end
  end

  describe "execute_enriched/1" do
    test "returns session with participation_records attached" do
      session_schema = insert(:program_session_schema)
      child = insert(:child_schema)

      insert(:participation_record_schema,
        session_id: session_schema.id,
        child_id: child.id,
        status: :registered
      )

      assert {:ok, session} = GetSessionWithRoster.execute_enriched(session_schema.id)
      assert %ProgramSession{} = session
      assert session.id == session_schema.id
      assert is_list(session.participation_records)
      assert length(session.participation_records) == 1
    end

    test "returns error when session not found" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = GetSessionWithRoster.execute_enriched(non_existent_id)
    end
  end
end
