defmodule PrimeYouth.Attendance.Application.UseCases.SubmitAttendanceTest do
  @moduledoc """
  Tests for SubmitAttendance use case.

  Tests batch submission of attendance records for payroll processing.
  """

  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Attendance.Application.UseCases.SubmitAttendance

  describe "execute/3" do
    test "returns error for empty record_ids list" do
      session = insert(:program_session_schema)
      submitter_id = Ecto.UUID.generate()

      assert {:error, :empty_record_ids} =
               SubmitAttendance.execute(session.id, [], submitter_id)
    end

    test "successfully submits multiple records atomically" do
      session = insert(:program_session_schema, status: "completed")
      child1 = insert(:child_schema)
      child2 = insert(:child_schema)
      submitter_id = Ecto.UUID.generate()

      record1 =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child1.id,
          status: "checked_out",
          submitted: false
        )

      record2 =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child2.id,
          status: "checked_out",
          submitted: false
        )

      assert {:ok, submitted_records} =
               SubmitAttendance.execute(session.id, [record1.id, record2.id], submitter_id)

      assert length(submitted_records) == 2
      assert Enum.all?(submitted_records, & &1.submitted)
    end

    test "returns error when record not found" do
      session = insert(:program_session_schema)
      submitter_id = Ecto.UUID.generate()
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               SubmitAttendance.execute(session.id, [non_existent_id], submitter_id)
    end

    test "returns error when some records not found" do
      session = insert(:program_session_schema, status: "completed")
      child = insert(:child_schema)
      submitter_id = Ecto.UUID.generate()

      record =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: "checked_out",
          submitted: false
        )

      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               SubmitAttendance.execute(session.id, [record.id, non_existent_id], submitter_id)
    end

    test "persists submitted status to database" do
      session = insert(:program_session_schema, status: "completed")
      child = insert(:child_schema)
      submitter_id = Ecto.UUID.generate()

      record =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: "checked_out",
          submitted: false
        )

      assert {:ok, [submitted_record]} =
               SubmitAttendance.execute(session.id, [record.id], submitter_id)

      assert submitted_record.submitted == true

      reloaded =
        Repo.get!(
          PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.AttendanceRecordSchema,
          record.id
        )

      assert reloaded.submitted == true
      assert reloaded.submitted_at != nil
      assert reloaded.submitted_by != nil
    end

    test "submits single record successfully" do
      session = insert(:program_session_schema, status: "completed")
      child = insert(:child_schema)
      submitter_id = Ecto.UUID.generate()

      record =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: "checked_out",
          submitted: false
        )

      assert {:ok, [submitted_record]} =
               SubmitAttendance.execute(session.id, [record.id], submitter_id)

      assert submitted_record.id == record.id
      assert submitted_record.submitted == true
    end
  end
end
