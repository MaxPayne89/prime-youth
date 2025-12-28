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
      provider = insert(:provider_schema)

      assert {:ok, record} =
               RecordCheckIn.execute(
                 session.id,
                 child.id,
                 provider.id,
                 "Child arrived happy"
               )

      assert %AttendanceRecord{} = record
      assert record.session_id == session.id
      assert record.child_id == child.id
      assert record.status == :checked_in
      assert record.check_in_notes == "Child arrived happy"
      assert record.check_in_by == provider.id
      assert record.check_in_at != nil
    end

    test "checks in with nil notes when not provided" do
      session = insert(:program_session_schema, status: "in_progress")
      child = insert(:child_schema)
      provider = insert(:provider_schema)

      assert {:ok, record} =
               RecordCheckIn.execute(session.id, child.id, provider.id)

      assert record.check_in_notes == nil
    end

    test "checks in existing expected record" do
      session = insert(:program_session_schema, status: "in_progress")
      child = insert(:child_schema)
      provider = insert(:provider_schema)

      _existing =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: "expected"
        )

      assert {:ok, record} =
               RecordCheckIn.execute(session.id, child.id, provider.id, "Late arrival")

      assert record.status == :checked_in
      assert record.check_in_notes == "Late arrival"
    end

    test "idempotent check-in succeeds for already checked-in record" do
      session = insert(:program_session_schema, status: "in_progress")
      child = insert(:child_schema)
      provider = insert(:provider_schema)
      original_check_in_time = DateTime.add(DateTime.utc_now(), -300, :second)

      _already_checked_in =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: "checked_in",
          check_in_at: original_check_in_time
        )

      # Idempotent: re-check-in succeeds and updates the record
      assert {:ok, record} =
               RecordCheckIn.execute(session.id, child.id, provider.id, "Updated notes")

      assert record.status == :checked_in
      assert record.check_in_notes == "Updated notes"
      # Check-in time was updated (idempotent upsert replaces fields)
      assert DateTime.compare(record.check_in_at, original_check_in_time) != :eq
    end

    test "persists check-in to database" do
      session = insert(:program_session_schema, status: "in_progress")
      child = insert(:child_schema)
      provider = insert(:provider_schema)

      {:ok, record} = RecordCheckIn.execute(session.id, child.id, provider.id)

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
