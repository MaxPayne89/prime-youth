defmodule PrimeYouth.Attendance.Application.UseCases.GetAttendanceHistoryTest do
  @moduledoc """
  Integration tests for GetAttendanceHistory use case.

  Tests attendance history retrieval with different filter types.
  """

  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Attendance.Application.UseCases.GetAttendanceHistory
  alias PrimeYouth.Attendance.Domain.Models.AttendanceRecord

  describe "execute/2 with :by_child filter" do
    test "returns all attendance records for a child" do
      child = insert(:child_schema)
      program = insert(:program_schema)

      session1 =
        insert(:program_session_schema,
          program_id: program.id,
          session_date: ~D[2025-02-15]
        )

      session2 =
        insert(:program_session_schema,
          program_id: program.id,
          session_date: ~D[2025-02-17]
        )

      insert(:attendance_record_schema, session_id: session1.id, child_id: child.id)
      insert(:attendance_record_schema, session_id: session2.id, child_id: child.id)

      records = GetAttendanceHistory.execute(:by_child, child.id)
      assert length(records) == 2
      assert Enum.all?(records, &match?(%AttendanceRecord{}, &1))
      assert Enum.all?(records, &(&1.child_id == child.id))
    end

    test "returns empty list when child has no records" do
      child = insert(:child_schema)

      records = GetAttendanceHistory.execute(:by_child, child.id)
      assert records == []
    end

    test "does not return records from other children" do
      child1 = insert(:child_schema)
      child2 = insert(:child_schema)
      session = insert(:program_session_schema)

      insert(:attendance_record_schema, session_id: session.id, child_id: child1.id)
      insert(:attendance_record_schema, session_id: session.id, child_id: child2.id)

      records = GetAttendanceHistory.execute(:by_child, child1.id)
      assert length(records) == 1
      assert hd(records).child_id == child1.id
    end
  end

  describe "execute/2 with :by_session filter" do
    test "returns all attendance records for a session" do
      session = insert(:program_session_schema)
      child1 = insert(:child_schema)
      child2 = insert(:child_schema)

      insert(:attendance_record_schema, session_id: session.id, child_id: child1.id)
      insert(:attendance_record_schema, session_id: session.id, child_id: child2.id)

      records = GetAttendanceHistory.execute(:by_session, session.id)
      assert length(records) == 2
      assert Enum.all?(records, &(&1.session_id == session.id))
    end

    test "returns empty list when session has no records" do
      session = insert(:program_session_schema)

      records = GetAttendanceHistory.execute(:by_session, session.id)
      assert records == []
    end

    test "does not return records from other sessions" do
      session1 = insert(:program_session_schema)
      session2 = insert(:program_session_schema)
      child = insert(:child_schema)

      insert(:attendance_record_schema, session_id: session1.id, child_id: child.id)
      insert(:attendance_record_schema, session_id: session2.id, child_id: child.id)

      records = GetAttendanceHistory.execute(:by_session, session1.id)
      assert length(records) == 1
      assert hd(records).session_id == session1.id
    end
  end

  describe "execute/2 with :by_parent filter" do
    test "returns all attendance records for a parent" do
      parent = insert(:parent_schema)
      child = insert(:child_schema)
      session1 = insert(:program_session_schema)
      session2 = insert(:program_session_schema)

      insert(:attendance_record_schema,
        session_id: session1.id,
        child_id: child.id,
        parent_id: parent.id
      )

      insert(:attendance_record_schema,
        session_id: session2.id,
        child_id: child.id,
        parent_id: parent.id
      )

      records = GetAttendanceHistory.execute(:by_parent, parent.id)
      assert length(records) == 2
      assert Enum.all?(records, &(&1.parent_id == parent.id))
    end

    test "returns empty list when parent has no records" do
      parent = insert(:parent_schema)

      records = GetAttendanceHistory.execute(:by_parent, parent.id)
      assert records == []
    end

    test "does not return records from other parents" do
      parent1 = insert(:parent_schema)
      parent2 = insert(:parent_schema)
      child1 = insert(:child_schema)
      child2 = insert(:child_schema)
      session = insert(:program_session_schema)

      insert(:attendance_record_schema,
        session_id: session.id,
        child_id: child1.id,
        parent_id: parent1.id
      )

      insert(:attendance_record_schema,
        session_id: session.id,
        child_id: child2.id,
        parent_id: parent2.id
      )

      records = GetAttendanceHistory.execute(:by_parent, parent1.id)
      assert length(records) == 1
      assert hd(records).parent_id == parent1.id
    end
  end

  describe "execute/2 with invalid filter" do
    test "returns error for invalid filter type" do
      assert {:error, {:invalid_filter_type, :unknown_filter}} =
               GetAttendanceHistory.execute(:unknown_filter, "some_value")
    end
  end
end
