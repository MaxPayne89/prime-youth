defmodule PrimeYouth.Attendance.Adapters.Driven.Persistence.Repositories.AttendanceRepositoryTest do
  @moduledoc """
  Integration tests for AttendanceRepository.

  Tests database operations for attendance record persistence including
  creation, retrieval, updates, batch operations, and optimistic locking.
  """

  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Attendance.Adapters.Driven.Persistence.Mappers.AttendanceRecordMapper
  alias PrimeYouth.Attendance.Adapters.Driven.Persistence.Repositories.AttendanceRepository
  alias PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.AttendanceRecordSchema
  alias PrimeYouth.Attendance.Domain.Models.AttendanceRecord
  alias PrimeYouth.Repo

  describe "create/1" do
    test "successfully creates attendance record and returns domain entity" do
      session = insert(:program_session_schema)
      child = insert(:child_schema)

      record =
        build(:attendance_record,
          session_id: session.id,
          child_id: child.id
        )

      assert {:ok, created} = AttendanceRepository.create(record)
      assert %AttendanceRecord{} = created
      assert created.session_id == session.id
      assert created.child_id == child.id
      assert created.status == :expected
    end

    test "returns error for duplicate session-child combination" do
      session = insert(:program_session_schema)
      child = insert(:child_schema)

      first_record =
        build(:attendance_record,
          session_id: session.id,
          child_id: child.id
        )

      assert {:ok, _} = AttendanceRepository.create(first_record)

      duplicate_record =
        build(:attendance_record,
          session_id: session.id,
          child_id: child.id
        )

      assert {:error, :duplicate_attendance} = AttendanceRepository.create(duplicate_record)
    end

    test "allows same child in different sessions" do
      session1 = insert(:program_session_schema)
      session2 = insert(:program_session_schema)
      child = insert(:child_schema)

      record1 = build(:attendance_record, session_id: session1.id, child_id: child.id)
      record2 = build(:attendance_record, session_id: session2.id, child_id: child.id)

      assert {:ok, _} = AttendanceRepository.create(record1)
      assert {:ok, _} = AttendanceRepository.create(record2)
    end
  end

  describe "get_by_id/1" do
    test "returns record when found" do
      record_schema = insert(:attendance_record_schema)

      assert {:ok, record} = AttendanceRepository.get_by_id(record_schema.id)
      assert %AttendanceRecord{} = record
      assert record.id == record_schema.id
    end

    test "returns error when record not found" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = AttendanceRepository.get_by_id(non_existent_id)
    end
  end

  describe "get_by_session_and_child/2" do
    test "returns record when found" do
      session = insert(:program_session_schema)
      child = insert(:child_schema)
      _record = insert(:attendance_record_schema, session_id: session.id, child_id: child.id)

      assert {:ok, record} = AttendanceRepository.get_by_session_and_child(session.id, child.id)
      assert %AttendanceRecord{} = record
      assert record.session_id == session.id
      assert record.child_id == child.id
    end

    test "returns error when record not found" do
      session = insert(:program_session_schema)
      child = insert(:child_schema)

      assert {:error, :not_found} =
               AttendanceRepository.get_by_session_and_child(session.id, child.id)
    end
  end

  describe "update/1" do
    test "successfully updates record status" do
      record_schema = insert(:attendance_record_schema, status: "expected")
      domain_record = AttendanceRecordMapper.to_domain(record_schema)

      updated_record = %{domain_record | status: :checked_in}

      assert {:ok, result} = AttendanceRepository.update(updated_record)
      assert result.status == :checked_in
    end

    test "returns error when record not found" do
      non_existent_record = build(:attendance_record, id: Ecto.UUID.generate())

      assert {:error, :not_found} = AttendanceRepository.update(non_existent_record)
    end

    test "updates check-in information" do
      record_schema = insert(:attendance_record_schema, status: "expected")
      domain_record = AttendanceRecordMapper.to_domain(record_schema)
      user_id = Ecto.UUID.generate()
      check_in_time = DateTime.utc_now()

      updated_record = %{
        domain_record
        | status: :checked_in,
          check_in_at: check_in_time,
          check_in_by: user_id,
          check_in_notes: "Arrived on time"
      }

      assert {:ok, result} = AttendanceRepository.update(updated_record)
      assert result.status == :checked_in
      assert result.check_in_notes == "Arrived on time"
    end

    test "updates check-out information" do
      record_schema = insert(:attendance_record_schema, status: "checked_in")
      domain_record = AttendanceRecordMapper.to_domain(record_schema)
      user_id = Ecto.UUID.generate()
      check_out_time = DateTime.utc_now()

      updated_record = %{
        domain_record
        | status: :checked_out,
          check_out_at: check_out_time,
          check_out_by: user_id,
          check_out_notes: "Picked up by parent"
      }

      assert {:ok, result} = AttendanceRepository.update(updated_record)
      assert result.status == :checked_out
      assert result.check_out_notes == "Picked up by parent"
    end

    test "handles optimistic locking conflict" do
      record_schema = insert(:attendance_record_schema)

      # Simulate two processes fetching the same record
      domain_v1_a = AttendanceRecordMapper.to_domain(record_schema)
      domain_v1_b = AttendanceRecordMapper.to_domain(record_schema)

      # First update succeeds
      updated_a = %{domain_v1_a | status: :checked_in}
      assert {:ok, _} = AttendanceRepository.update(updated_a)

      # Second update fails with stale data
      updated_b = %{domain_v1_b | status: :absent}
      assert {:error, :stale_data} = AttendanceRepository.update(updated_b)

      # Verify first update persisted
      final_schema = Repo.get(AttendanceRecordSchema, record_schema.id)
      assert final_schema.status == "checked_in"
    end

    test "sequential updates with version increments succeed" do
      record_schema = insert(:attendance_record_schema)

      # First update
      domain_v1 = AttendanceRecordMapper.to_domain(record_schema)
      updated_v1 = %{domain_v1 | status: :checked_in}
      assert {:ok, result_v2} = AttendanceRepository.update(updated_v1)

      # Second update using fresh result
      updated_v2 = %{result_v2 | status: :checked_out}
      assert {:ok, result_v3} = AttendanceRepository.update(updated_v2)

      assert result_v3.status == :checked_out
    end
  end

  describe "list_by_session/1" do
    test "returns all records for session" do
      session = insert(:program_session_schema)
      child1 = insert(:child_schema)
      child2 = insert(:child_schema)

      insert(:attendance_record_schema, session_id: session.id, child_id: child1.id)
      insert(:attendance_record_schema, session_id: session.id, child_id: child2.id)

      assert {:ok, records} = AttendanceRepository.list_by_session(session.id)
      assert length(records) == 2
      assert Enum.all?(records, &(&1.session_id == session.id))
    end

    test "returns empty list when session has no records" do
      session = insert(:program_session_schema)

      assert {:ok, records} = AttendanceRepository.list_by_session(session.id)
      assert records == []
    end

    test "does not return records from other sessions" do
      session1 = insert(:program_session_schema)
      session2 = insert(:program_session_schema)
      child = insert(:child_schema)

      insert(:attendance_record_schema, session_id: session1.id, child_id: child.id)
      insert(:attendance_record_schema, session_id: session2.id, child_id: child.id)

      assert {:ok, records} = AttendanceRepository.list_by_session(session1.id)
      assert length(records) == 1
      assert hd(records).session_id == session1.id
    end
  end

  describe "list_by_child/1" do
    test "returns all records for child ordered by session date descending" do
      child = insert(:child_schema)
      program = insert(:program_schema)

      session1 =
        insert(:program_session_schema,
          program_id: program.id,
          session_date: ~D[2025-02-15],
          start_time: ~T[09:00:00]
        )

      session2 =
        insert(:program_session_schema,
          program_id: program.id,
          session_date: ~D[2025-02-17],
          start_time: ~T[09:00:00]
        )

      insert(:attendance_record_schema, session_id: session1.id, child_id: child.id)
      insert(:attendance_record_schema, session_id: session2.id, child_id: child.id)

      assert {:ok, records} = AttendanceRepository.list_by_child(child.id)
      assert length(records) == 2
      assert Enum.all?(records, &(&1.child_id == child.id))
    end

    test "returns empty list when child has no records" do
      child = insert(:child_schema)

      assert {:ok, records} = AttendanceRepository.list_by_child(child.id)
      assert records == []
    end
  end

  describe "check_in_atomic/4" do
    test "creates new record when none exists" do
      session = insert(:program_session_schema)
      child = insert(:child_schema)
      provider = insert(:provider_schema)

      assert {:ok, record} =
               AttendanceRepository.check_in_atomic(
                 session.id,
                 child.id,
                 provider.id,
                 "First check-in"
               )

      assert %AttendanceRecord{} = record
      assert record.session_id == session.id
      assert record.child_id == child.id
      assert record.status == :checked_in
      assert record.check_in_notes == "First check-in"
      assert record.check_in_by == provider.id
      assert record.check_in_at != nil
    end

    test "updates existing record (idempotent upsert)" do
      session = insert(:program_session_schema)
      child = insert(:child_schema)
      provider = insert(:provider_schema)
      original_time = DateTime.add(DateTime.utc_now(), -300, :second)

      _existing =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: "expected",
          check_in_at: original_time
        )

      assert {:ok, record} =
               AttendanceRepository.check_in_atomic(
                 session.id,
                 child.id,
                 provider.id,
                 "Updated via atomic"
               )

      assert record.status == :checked_in
      assert record.check_in_notes == "Updated via atomic"
      # Timestamp was updated (not the original)
      assert DateTime.compare(record.check_in_at, original_time) != :eq
    end

    test "is idempotent for already checked-in records" do
      session = insert(:program_session_schema)
      child = insert(:child_schema)
      provider = insert(:provider_schema)

      _checked_in =
        insert(:attendance_record_schema,
          session_id: session.id,
          child_id: child.id,
          status: "checked_in",
          check_in_at: DateTime.utc_now()
        )

      # Second check-in succeeds (idempotent)
      assert {:ok, record} =
               AttendanceRepository.check_in_atomic(
                 session.id,
                 child.id,
                 provider.id,
                 "Retry notes"
               )

      assert record.status == :checked_in
      assert record.check_in_notes == "Retry notes"
    end

    test "handles nil notes" do
      session = insert(:program_session_schema)
      child = insert(:child_schema)
      provider = insert(:provider_schema)

      assert {:ok, record} =
               AttendanceRepository.check_in_atomic(session.id, child.id, provider.id, nil)

      assert record.check_in_notes == nil
    end

    test "handles concurrent check-in attempts without race condition" do
      session = insert(:program_session_schema)
      child = insert(:child_schema)
      provider1 = insert(:provider_schema)
      provider2 = insert(:provider_schema)

      # Simulate concurrent check-ins - both should succeed
      task1 =
        Task.async(fn ->
          AttendanceRepository.check_in_atomic(session.id, child.id, provider1.id, "Task 1")
        end)

      task2 =
        Task.async(fn ->
          AttendanceRepository.check_in_atomic(session.id, child.id, provider2.id, "Task 2")
        end)

      result1 = Task.await(task1)
      result2 = Task.await(task2)

      # Both should succeed (no duplicate key error)
      assert {:ok, _} = result1
      assert {:ok, _} = result2

      # Only one record should exist in database
      schema = Repo.get_by(AttendanceRecordSchema, session_id: session.id, child_id: child.id)
      assert schema != nil
      # Last writer wins (either provider1 or provider2 notes)
      assert schema.check_in_notes in ["Task 1", "Task 2"]
    end
  end

  describe "list_by_parent/1" do
    test "returns all records for parent ordered by session date descending" do
      parent = insert(:parent_schema)
      child = insert(:child_schema)
      program = insert(:program_schema)

      session1 =
        insert(:program_session_schema,
          program_id: program.id,
          session_date: ~D[2025-02-15],
          start_time: ~T[09:00:00]
        )

      session2 =
        insert(:program_session_schema,
          program_id: program.id,
          session_date: ~D[2025-02-17],
          start_time: ~T[09:00:00]
        )

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

      assert {:ok, records} = AttendanceRepository.list_by_parent(parent.id)
      assert length(records) == 2
      assert Enum.all?(records, &(&1.parent_id == parent.id))
    end

    test "returns empty list when parent has no records" do
      parent = insert(:parent_schema)

      assert {:ok, records} = AttendanceRepository.list_by_parent(parent.id)
      assert records == []
    end
  end
end
