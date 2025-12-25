defmodule PrimeYouth.Attendance.Application.UseCases.RecordCheckInTest do
  @moduledoc """
  Integration tests for RecordCheckIn use case.

  Tests check-in recording with new record creation and existing record updates.
  """

  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Attendance.Application.UseCases.RecordCheckIn
  alias PrimeYouth.Attendance.Domain.Models.AttendanceRecord

  describe "execute/4" do
    test "creates new attendance record and checks in" do
      session = insert(:program_session_schema, status: "in_progress")
      child = insert(:child_schema)
      provider_id = Ecto.UUID.generate()

      assert {:ok, record} =
               RecordCheckIn.execute(
                 session.id,
                 child.id,
                 provider_id,
                 "Child arrived happy"
               )

      assert %AttendanceRecord{} = record
      assert record.session_id == session.id
      assert record.child_id == child.id
      assert record.status == :checked_in
      assert record.check_in_notes == "Child arrived happy"
      assert record.check_in_by == provider_id
      assert record.check_in_at != nil
    end

    test "checks in with nil notes when not provided" do
      session = insert(:program_session_schema, status: "in_progress")
      child = insert(:child_schema)
      provider_id = Ecto.UUID.generate()

      assert {:ok, record} =
               RecordCheckIn.execute(session.id, child.id, provider_id)

      assert record.check_in_notes == nil
    end

    test "checks in existing expected record" do
      session = insert(:program_session_schema, status: "in_progress")
      child = insert(:child_schema)
      provider_id = Ecto.UUID.generate()

      _existing =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: "expected"
        )

      assert {:ok, record} =
               RecordCheckIn.execute(session.id, child.id, provider_id, "Late arrival")

      assert record.status == :checked_in
      assert record.check_in_notes == "Late arrival"
    end

    test "returns error when checking in already checked-in record" do
      session = insert(:program_session_schema, status: "in_progress")
      child = insert(:child_schema)
      provider_id = Ecto.UUID.generate()

      _already_checked_in =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: "checked_in",
          check_in_at: DateTime.utc_now()
        )

      assert {:error, message} =
               RecordCheckIn.execute(session.id, child.id, provider_id)

      assert message =~ "Cannot check in"
    end

    test "returns error when checking in submitted record" do
      session = insert(:program_session_schema, status: "in_progress")
      child = insert(:child_schema)
      provider_id = Ecto.UUID.generate()

      _submitted =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: "expected",
          submitted: true,
          submitted_at: DateTime.utc_now()
        )

      assert {:error, message} =
               RecordCheckIn.execute(session.id, child.id, provider_id)

      assert message =~ "submitted"
    end

    test "persists check-in to database" do
      session = insert(:program_session_schema, status: "in_progress")
      child = insert(:child_schema)
      provider_id = Ecto.UUID.generate()

      {:ok, record} = RecordCheckIn.execute(session.id, child.id, provider_id)

      reloaded =
        PrimeYouth.Repo.get(
          PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.AttendanceRecordSchema,
          record.id
        )

      assert reloaded.status == "checked_in"
      assert reloaded.check_in_at != nil
    end
  end
end
