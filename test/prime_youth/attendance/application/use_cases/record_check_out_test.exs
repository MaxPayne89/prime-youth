defmodule PrimeYouth.Attendance.Application.UseCases.RecordCheckOutTest do
  @moduledoc """
  Integration tests for RecordCheckOut use case.

  Tests check-out recording for children already checked in.
  """

  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Attendance.Application.UseCases.RecordCheckOut
  alias PrimeYouth.Attendance.Domain.Models.AttendanceRecord

  describe "execute/4" do
    test "successfully checks out a checked-in record" do
      session = insert(:program_session_schema, status: "in_progress")
      child = insert(:child_schema)
      provider_id = Ecto.UUID.generate()
      check_in_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      _checked_in =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: "checked_in",
          check_in_at: check_in_time
        )

      assert {:ok, record} =
               RecordCheckOut.execute(
                 session.id,
                 child.id,
                 provider_id,
                 "Picked up by parent"
               )

      assert %AttendanceRecord{} = record
      assert record.status == :checked_out
      assert record.check_out_notes == "Picked up by parent"
      assert record.check_out_by == provider_id
      assert record.check_out_at != nil
    end

    test "checks out with nil notes when not provided" do
      session = insert(:program_session_schema, status: "in_progress")
      child = insert(:child_schema)
      provider_id = Ecto.UUID.generate()
      check_in_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      _checked_in =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: "checked_in",
          check_in_at: check_in_time
        )

      assert {:ok, record} =
               RecordCheckOut.execute(session.id, child.id, provider_id)

      assert record.check_out_notes == nil
    end

    test "returns error when no record exists" do
      session = insert(:program_session_schema, status: "in_progress")
      child = insert(:child_schema)
      provider_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               RecordCheckOut.execute(session.id, child.id, provider_id)
    end

    test "returns error when record is not checked in" do
      session = insert(:program_session_schema, status: "in_progress")
      child = insert(:child_schema)
      provider_id = Ecto.UUID.generate()

      _expected =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: "expected"
        )

      assert {:error, message} =
               RecordCheckOut.execute(session.id, child.id, provider_id)

      assert message =~ "Cannot check out"
    end

    test "returns error when record is already checked out" do
      session = insert(:program_session_schema, status: "in_progress")
      child = insert(:child_schema)
      provider_id = Ecto.UUID.generate()
      check_in_time = DateTime.add(DateTime.utc_now(), -3600, :second)
      check_out_time = DateTime.utc_now()

      _checked_out =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: "checked_out",
          check_in_at: check_in_time,
          check_out_at: check_out_time
        )

      assert {:error, message} =
               RecordCheckOut.execute(session.id, child.id, provider_id)

      assert message =~ "Cannot check out"
    end

    test "returns error when record is submitted" do
      session = insert(:program_session_schema, status: "in_progress")
      child = insert(:child_schema)
      provider_id = Ecto.UUID.generate()
      check_in_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      _submitted =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: "checked_in",
          check_in_at: check_in_time,
          submitted: true,
          submitted_at: DateTime.utc_now()
        )

      assert {:error, message} =
               RecordCheckOut.execute(session.id, child.id, provider_id)

      assert message =~ "submitted"
    end

    test "persists check-out to database" do
      session = insert(:program_session_schema, status: "in_progress")
      child = insert(:child_schema)
      provider_id = Ecto.UUID.generate()
      check_in_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      existing =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: "checked_in",
          check_in_at: check_in_time
        )

      {:ok, _record} = RecordCheckOut.execute(session.id, child.id, provider_id)

      reloaded =
        PrimeYouth.Repo.get(
          PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.AttendanceRecordSchema,
          existing.id
        )

      assert reloaded.status == "checked_out"
      assert reloaded.check_out_at != nil
    end
  end
end
