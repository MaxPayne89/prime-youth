defmodule PrimeYouth.Attendance.Application.UseCases.GetSessionWithRosterTest do
  @moduledoc """
  Integration tests for GetSessionWithRoster use case.

  Tests retrieving a session with its attendance roster.
  """

  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Attendance.Application.UseCases.GetSessionWithRoster
  alias PrimeYouth.Attendance.Domain.Models.AttendanceRecord
  alias PrimeYouth.Attendance.Domain.Models.ProgramSession

  describe "execute/1" do
    test "returns session with attendance records" do
      session_schema = insert(:program_session_schema)
      child1 = insert(:child_schema)
      child2 = insert(:child_schema)

      insert(:attendance_record_schema,
        session_id: session_schema.id,
        child_id: child1.id,
        status: "expected"
      )

      insert(:attendance_record_schema,
        session_id: session_schema.id,
        child_id: child2.id,
        status: "checked_in"
      )

      assert {:ok, result} = GetSessionWithRoster.execute(session_schema.id)
      assert %ProgramSession{} = result
      assert result.id == session_schema.id
      assert is_list(result.attendance_records)
      assert length(result.attendance_records) == 2
      assert Enum.all?(result.attendance_records, &match?(%AttendanceRecord{}, &1))
    end

    test "returns session with empty roster when no attendance records" do
      session_schema = insert(:program_session_schema)

      assert {:ok, result} = GetSessionWithRoster.execute(session_schema.id)
      assert %ProgramSession{} = result
      assert result.attendance_records == []
    end

    test "returns error when session not found" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = GetSessionWithRoster.execute(non_existent_id)
    end

    test "includes all attendance record details" do
      session_schema = insert(:program_session_schema)
      parent = insert(:parent_schema)
      child = insert(:child_schema)
      check_in_time = DateTime.utc_now()

      insert(:attendance_record_schema,
        session_id: session_schema.id,
        child_id: child.id,
        parent_id: parent.id,
        status: "checked_in",
        check_in_at: check_in_time,
        check_in_notes: "Arrived on time"
      )

      assert {:ok, result} = GetSessionWithRoster.execute(session_schema.id)
      assert [record] = result.attendance_records
      assert record.child_id == child.id
      assert record.parent_id == parent.id
      assert record.status == :checked_in
      assert record.check_in_notes == "Arrived on time"
    end

    test "only returns attendance records for specified session" do
      session1 = insert(:program_session_schema)
      session2 = insert(:program_session_schema)
      child = insert(:child_schema)

      insert(:attendance_record_schema,
        session_id: session1.id,
        child_id: child.id,
        status: "expected"
      )

      insert(:attendance_record_schema,
        session_id: session2.id,
        child_id: child.id,
        status: "checked_in"
      )

      assert {:ok, result} = GetSessionWithRoster.execute(session1.id)
      assert length(result.attendance_records) == 1
      assert hd(result.attendance_records).session_id == session1.id
    end
  end
end
