defmodule PrimeYouth.Attendance.Domain.Models.AttendanceRecordTest do
  @moduledoc """
  Tests for AttendanceRecord domain entity.

  Covers validation, status transitions, and check-in/out flows.
  """

  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Attendance.Domain.Models.AttendanceRecord

  describe "new/1" do
    test "creates a valid attendance record with required fields" do
      attrs = %{
        id: Ecto.UUID.generate(),
        session_id: Ecto.UUID.generate(),
        child_id: Ecto.UUID.generate(),
        status: :expected
      }

      assert {:ok, record} = AttendanceRecord.new(attrs)
      assert record.id == attrs.id
      assert record.session_id == attrs.session_id
      assert record.child_id == attrs.child_id
      assert record.status == :expected
    end

    test "creates record with optional fields" do
      parent_id = Ecto.UUID.generate()
      provider_id = Ecto.UUID.generate()

      attrs = %{
        id: Ecto.UUID.generate(),
        session_id: Ecto.UUID.generate(),
        child_id: Ecto.UUID.generate(),
        parent_id: parent_id,
        provider_id: provider_id,
        status: :expected
      }

      assert {:ok, record} = AttendanceRecord.new(attrs)
      assert record.parent_id == parent_id
      assert record.provider_id == provider_id
    end

    test "returns error for invalid status" do
      attrs = %{
        id: Ecto.UUID.generate(),
        session_id: Ecto.UUID.generate(),
        child_id: Ecto.UUID.generate(),
        status: :invalid_status
      }

      assert {:error, errors} = AttendanceRecord.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "Invalid status"))
    end

    test "returns error when check_out_at is before check_in_at" do
      check_in_at = ~U[2025-01-15 14:00:00Z]
      check_out_at = ~U[2025-01-15 09:00:00Z]

      attrs = %{
        id: Ecto.UUID.generate(),
        session_id: Ecto.UUID.generate(),
        child_id: Ecto.UUID.generate(),
        status: :checked_out,
        check_in_at: check_in_at,
        check_out_at: check_out_at
      }

      assert {:error, errors} = AttendanceRecord.new(attrs)
      assert "Check-out time cannot be before check-in time" in errors
    end
  end

  describe "valid?/1" do
    test "returns true for valid record" do
      record = build(:attendance_record)
      assert AttendanceRecord.valid?(record)
    end

    test "returns false for invalid record" do
      record =
        build(:attendance_record,
          check_in_at: ~U[2025-01-15 14:00:00Z],
          check_out_at: ~U[2025-01-15 09:00:00Z]
        )

      refute AttendanceRecord.valid?(record)
    end
  end

  describe "check_in/4" do
    test "transitions :expected record to :checked_in" do
      record = build(:attendance_record, status: :expected)
      check_in_at = DateTime.utc_now()
      provider_id = Ecto.UUID.generate()

      assert {:ok, checked_in} =
               AttendanceRecord.check_in(record, check_in_at, "Arrived early", provider_id)

      assert checked_in.status == :checked_in
      assert checked_in.check_in_at == check_in_at
      assert checked_in.check_in_notes == "Arrived early"
      assert checked_in.check_in_by == provider_id
    end

    test "allows nil check_in_notes" do
      record = build(:attendance_record, status: :expected)
      check_in_at = DateTime.utc_now()
      provider_id = Ecto.UUID.generate()

      assert {:ok, checked_in} =
               AttendanceRecord.check_in(record, check_in_at, nil, provider_id)

      assert checked_in.check_in_notes == nil
    end

    test "returns error when checking in already checked-in record" do
      record = build(:checked_in_attendance_record)
      check_in_at = DateTime.utc_now()
      provider_id = Ecto.UUID.generate()

      assert {:error, message} =
               AttendanceRecord.check_in(record, check_in_at, nil, provider_id)

      assert message =~ "Cannot check in with status: checked_in"
    end

    test "returns error when checking in checked-out record" do
      record = build(:checked_out_attendance_record)
      check_in_at = DateTime.utc_now()
      provider_id = Ecto.UUID.generate()

      assert {:error, message} =
               AttendanceRecord.check_in(record, check_in_at, nil, provider_id)

      assert message =~ "Cannot check in with status: checked_out"
    end
  end

  describe "check_out/4" do
    test "transitions :checked_in record to :checked_out" do
      check_in_at = DateTime.add(DateTime.utc_now(), -3600, :second)

      record =
        build(:attendance_record,
          status: :checked_in,
          check_in_at: check_in_at,
          check_in_by: Ecto.UUID.generate()
        )

      check_out_at = DateTime.utc_now()
      provider_id = Ecto.UUID.generate()

      assert {:ok, checked_out} =
               AttendanceRecord.check_out(record, check_out_at, "Picked up by mom", provider_id)

      assert checked_out.status == :checked_out
      assert checked_out.check_out_at == check_out_at
      assert checked_out.check_out_notes == "Picked up by mom"
      assert checked_out.check_out_by == provider_id
    end

    test "allows nil check_out_notes" do
      check_in_at = DateTime.add(DateTime.utc_now(), -3600, :second)

      record =
        build(:attendance_record,
          status: :checked_in,
          check_in_at: check_in_at,
          check_in_by: Ecto.UUID.generate()
        )

      check_out_at = DateTime.utc_now()
      provider_id = Ecto.UUID.generate()

      assert {:ok, checked_out} =
               AttendanceRecord.check_out(record, check_out_at, nil, provider_id)

      assert checked_out.check_out_notes == nil
    end

    test "returns error when check_out_at is before check_in_at" do
      check_in_at = DateTime.utc_now()

      record =
        build(:attendance_record,
          status: :checked_in,
          check_in_at: check_in_at,
          check_in_by: Ecto.UUID.generate()
        )

      check_out_at = DateTime.add(check_in_at, -3600, :second)
      provider_id = Ecto.UUID.generate()

      assert {:error, message} =
               AttendanceRecord.check_out(record, check_out_at, nil, provider_id)

      assert message =~ "Check-out time cannot be before check-in time"
    end

    test "returns error when checking out :expected record" do
      record = build(:attendance_record, status: :expected)
      check_out_at = DateTime.utc_now()
      provider_id = Ecto.UUID.generate()

      assert {:error, message} =
               AttendanceRecord.check_out(record, check_out_at, nil, provider_id)

      assert message =~ "Cannot check out with status: expected"
    end

    test "returns error when checking out already checked-out record" do
      record = build(:checked_out_attendance_record)
      check_out_at = DateTime.utc_now()
      provider_id = Ecto.UUID.generate()

      assert {:error, message} =
               AttendanceRecord.check_out(record, check_out_at, nil, provider_id)

      assert message =~ "Cannot check out with status: checked_out"
    end
  end

  describe "mark_absent/1" do
    test "transitions :expected record to :absent" do
      record = build(:attendance_record, status: :expected)

      assert {:ok, absent} = AttendanceRecord.mark_absent(record)
      assert absent.status == :absent
    end

    test "transitions :checked_in record to :absent and clears check-in data" do
      record = build(:checked_in_attendance_record)

      assert {:ok, absent} = AttendanceRecord.mark_absent(record)
      assert absent.status == :absent
      assert absent.check_in_at == nil
      assert absent.check_in_notes == nil
      assert absent.check_in_by == nil
    end

    test "returns error when marking :checked_out as absent" do
      record = build(:checked_out_attendance_record)

      assert {:error, message} = AttendanceRecord.mark_absent(record)
      assert message =~ "Cannot mark as absent with status: checked_out"
    end
  end

  describe "mark_excused/1" do
    test "transitions :expected record to :excused" do
      record = build(:attendance_record, status: :expected)

      assert {:ok, excused} = AttendanceRecord.mark_excused(record)
      assert excused.status == :excused
    end

    test "transitions :checked_in record to :excused and clears check-in data" do
      record = build(:checked_in_attendance_record)

      assert {:ok, excused} = AttendanceRecord.mark_excused(record)
      assert excused.status == :excused
      assert excused.check_in_at == nil
      assert excused.check_in_notes == nil
      assert excused.check_in_by == nil
    end

    test "returns error when marking :checked_out as excused" do
      record = build(:checked_out_attendance_record)

      assert {:error, message} = AttendanceRecord.mark_excused(record)
      assert message =~ "Cannot mark as excused with status: checked_out"
    end
  end

  describe "checked_in?/1" do
    test "returns true for :checked_in status" do
      record = build(:checked_in_attendance_record)
      assert AttendanceRecord.checked_in?(record)
    end

    test "returns true for :checked_out status" do
      record = build(:checked_out_attendance_record)
      assert AttendanceRecord.checked_in?(record)
    end

    test "returns false for :expected status" do
      record = build(:attendance_record, status: :expected)
      refute AttendanceRecord.checked_in?(record)
    end

    test "returns false for :absent status" do
      record = build(:attendance_record, status: :absent)
      refute AttendanceRecord.checked_in?(record)
    end
  end

  describe "checked_out?/1" do
    test "returns true for :checked_out status" do
      record = build(:checked_out_attendance_record)
      assert AttendanceRecord.checked_out?(record)
    end

    test "returns false for other statuses" do
      refute AttendanceRecord.checked_out?(build(:attendance_record, status: :expected))
      refute AttendanceRecord.checked_out?(build(:checked_in_attendance_record))
      refute AttendanceRecord.checked_out?(build(:attendance_record, status: :absent))
    end
  end

  describe "can_check_out?/1" do
    test "returns true for :checked_in record" do
      record = build(:checked_in_attendance_record)
      assert AttendanceRecord.can_check_out?(record)
    end

    test "returns false for :expected record" do
      record = build(:attendance_record, status: :expected)
      refute AttendanceRecord.can_check_out?(record)
    end
  end

  describe "finalized?/1" do
    test "returns true for :checked_out record" do
      record = build(:checked_out_attendance_record)
      assert AttendanceRecord.finalized?(record)
    end

    test "returns true for :absent record" do
      record = build(:attendance_record, status: :absent)
      assert AttendanceRecord.finalized?(record)
    end

    test "returns true for :excused record" do
      record = build(:attendance_record, status: :excused)
      assert AttendanceRecord.finalized?(record)
    end

    test "returns false for non-finalized statuses" do
      refute AttendanceRecord.finalized?(build(:attendance_record, status: :expected))
      refute AttendanceRecord.finalized?(build(:checked_in_attendance_record))
    end
  end

  describe "attendance_duration/1" do
    test "calculates duration in seconds for completed attendance" do
      check_in_at = ~U[2025-01-15 09:00:00Z]
      check_out_at = ~U[2025-01-15 12:30:00Z]

      record =
        build(:attendance_record,
          status: :checked_out,
          check_in_at: check_in_at,
          check_out_at: check_out_at
        )

      assert AttendanceRecord.attendance_duration(record) == 12_600
    end

    test "returns nil when check_in_at is nil" do
      record = build(:attendance_record, check_in_at: nil, check_out_at: nil)
      assert AttendanceRecord.attendance_duration(record) == nil
    end

    test "returns nil when check_out_at is nil" do
      record = build(:checked_in_attendance_record)
      assert AttendanceRecord.attendance_duration(record) == nil
    end

    test "returns 0 for same check-in and check-out time" do
      now = DateTime.utc_now()

      record =
        build(:attendance_record,
          status: :checked_out,
          check_in_at: now,
          check_out_at: now
        )

      assert AttendanceRecord.attendance_duration(record) == 0
    end
  end
end
