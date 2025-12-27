defmodule PrimeYouth.Attendance.Application.UseCases.GetAttendanceRecordTest do
  @moduledoc """
  Integration tests for GetAttendanceRecord use case.

  Tests retrieval of attendance records by ID.
  """

  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Attendance.Application.UseCases.GetAttendanceRecord
  alias PrimeYouth.Attendance.Domain.Models.AttendanceRecord

  describe "execute/1" do
    test "returns attendance record when found" do
      record_schema = insert(:attendance_record_schema)

      assert {:ok, record} = GetAttendanceRecord.execute(record_schema.id)
      assert %AttendanceRecord{} = record
      assert record.id == record_schema.id
    end

    test "returns error when record not found" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = GetAttendanceRecord.execute(non_existent_id)
    end

    test "includes all record details" do
      session = insert(:program_session_schema)
      child = insert(:child_schema)
      parent = insert(:parent_schema)
      staff_id = Ecto.UUID.generate()
      check_in_time = DateTime.add(DateTime.utc_now(), -3600, :second)
      check_out_time = DateTime.utc_now()

      record_schema =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          parent_id: parent.id,
          status: "checked_out",
          check_in_at: check_in_time,
          check_in_by: staff_id,
          check_in_notes: "Arrived on time",
          check_out_at: check_out_time,
          check_out_by: staff_id,
          check_out_notes: "Picked up by parent"
        )

      assert {:ok, record} = GetAttendanceRecord.execute(record_schema.id)
      assert record.session_id == session.id
      assert record.child_id == child.id
      assert record.parent_id == parent.id
      assert record.status == :checked_out
      assert record.check_in_notes == "Arrived on time"
      assert record.check_out_notes == "Picked up by parent"
    end
  end
end
