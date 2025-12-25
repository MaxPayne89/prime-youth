defmodule PrimeYouth.Attendance.Domain.Models.ProgramSessionTest do
  @moduledoc """
  Tests for ProgramSession domain entity.

  Covers validation, status transitions, and predicate functions.
  """

  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Attendance.Domain.Models.ProgramSession

  describe "new/1" do
    test "creates a valid session with all required fields" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        session_date: ~D[2025-01-15],
        start_time: ~T[09:00:00],
        end_time: ~T[12:00:00],
        max_capacity: 20,
        status: :scheduled
      }

      assert {:ok, session} = ProgramSession.new(attrs)
      assert session.id == attrs.id
      assert session.program_id == attrs.program_id
      assert session.session_date == ~D[2025-01-15]
      assert session.start_time == ~T[09:00:00]
      assert session.end_time == ~T[12:00:00]
      assert session.max_capacity == 20
      assert session.status == :scheduled
    end

    test "creates session with optional notes" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        session_date: ~D[2025-01-15],
        start_time: ~T[09:00:00],
        end_time: ~T[12:00:00],
        max_capacity: 20,
        status: :scheduled,
        notes: "Special equipment needed"
      }

      assert {:ok, session} = ProgramSession.new(attrs)
      assert session.notes == "Special equipment needed"
    end

    test "allows max_capacity of 0 for unlimited capacity" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        session_date: ~D[2025-01-15],
        start_time: ~T[09:00:00],
        end_time: ~T[12:00:00],
        max_capacity: 0,
        status: :scheduled
      }

      assert {:ok, session} = ProgramSession.new(attrs)
      assert session.max_capacity == 0
    end

    test "returns error for negative max_capacity" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        session_date: ~D[2025-01-15],
        start_time: ~T[09:00:00],
        end_time: ~T[12:00:00],
        max_capacity: -5,
        status: :scheduled
      }

      assert {:error, errors} = ProgramSession.new(attrs)
      assert "Max capacity cannot be negative" in errors
    end

    test "returns error when end_time is before start_time" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        session_date: ~D[2025-01-15],
        start_time: ~T[14:00:00],
        end_time: ~T[09:00:00],
        max_capacity: 20,
        status: :scheduled
      }

      assert {:error, errors} = ProgramSession.new(attrs)
      assert "End time must be after start time" in errors
    end

    test "returns error when end_time equals start_time" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        session_date: ~D[2025-01-15],
        start_time: ~T[09:00:00],
        end_time: ~T[09:00:00],
        max_capacity: 20,
        status: :scheduled
      }

      assert {:error, errors} = ProgramSession.new(attrs)
      assert "End time must be after start time" in errors
    end

    test "returns error for invalid status" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        session_date: ~D[2025-01-15],
        start_time: ~T[09:00:00],
        end_time: ~T[12:00:00],
        max_capacity: 20,
        status: :invalid_status
      }

      assert {:error, errors} = ProgramSession.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "Invalid status"))
    end

    test "returns error for invalid session_date" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        session_date: "not-a-date",
        start_time: ~T[09:00:00],
        end_time: ~T[12:00:00],
        max_capacity: 20,
        status: :scheduled
      }

      assert {:error, errors} = ProgramSession.new(attrs)
      assert "Session date must be a valid Date struct" in errors
    end

    test "accumulates multiple validation errors" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        session_date: ~D[2025-01-15],
        start_time: ~T[14:00:00],
        end_time: ~T[09:00:00],
        max_capacity: -5,
        status: :invalid_status
      }

      assert {:error, errors} = ProgramSession.new(attrs)
      assert length(errors) >= 2
    end
  end

  describe "valid?/1" do
    test "returns true for valid session" do
      session = build(:program_session)
      assert ProgramSession.valid?(session)
    end

    test "returns false for invalid session" do
      session = build(:program_session, max_capacity: -1)
      refute ProgramSession.valid?(session)
    end
  end

  describe "start_session/1" do
    test "transitions :scheduled session to :in_progress" do
      session = build(:program_session, status: :scheduled)

      assert {:ok, started} = ProgramSession.start_session(session)
      assert started.status == :in_progress
    end

    test "returns error when starting :in_progress session" do
      session = build(:program_session, status: :in_progress)

      assert {:error, message} = ProgramSession.start_session(session)
      assert message =~ "Cannot start session with status: in_progress"
    end

    test "returns error when starting :completed session" do
      session = build(:program_session, status: :completed)

      assert {:error, message} = ProgramSession.start_session(session)
      assert message =~ "Cannot start session with status: completed"
    end

    test "returns error when starting :cancelled session" do
      session = build(:program_session, status: :cancelled)

      assert {:error, message} = ProgramSession.start_session(session)
      assert message =~ "Cannot start session with status: cancelled"
    end
  end

  describe "complete_session/1" do
    test "transitions :in_progress session to :completed" do
      session = build(:program_session, status: :in_progress)

      assert {:ok, completed} = ProgramSession.complete_session(session)
      assert completed.status == :completed
    end

    test "returns error when completing :scheduled session" do
      session = build(:program_session, status: :scheduled)

      assert {:error, message} = ProgramSession.complete_session(session)
      assert message =~ "Cannot complete session with status: scheduled"
    end

    test "returns error when completing :completed session" do
      session = build(:program_session, status: :completed)

      assert {:error, message} = ProgramSession.complete_session(session)
      assert message =~ "Cannot complete session with status: completed"
    end

    test "returns error when completing :cancelled session" do
      session = build(:program_session, status: :cancelled)

      assert {:error, message} = ProgramSession.complete_session(session)
      assert message =~ "Cannot complete session with status: cancelled"
    end
  end

  describe "cancel_session/1" do
    test "transitions :scheduled session to :cancelled" do
      session = build(:program_session, status: :scheduled)

      assert {:ok, cancelled} = ProgramSession.cancel_session(session)
      assert cancelled.status == :cancelled
    end

    test "transitions :in_progress session to :cancelled" do
      session = build(:program_session, status: :in_progress)

      assert {:ok, cancelled} = ProgramSession.cancel_session(session)
      assert cancelled.status == :cancelled
    end

    test "returns error when cancelling :completed session" do
      session = build(:program_session, status: :completed)

      assert {:error, message} = ProgramSession.cancel_session(session)
      assert message =~ "Cannot cancel session with status: completed"
    end

    test "returns error when cancelling :cancelled session" do
      session = build(:program_session, status: :cancelled)

      assert {:error, message} = ProgramSession.cancel_session(session)
      assert message =~ "Cannot cancel session with status: cancelled"
    end
  end

  describe "can_start?/1" do
    test "returns true for :scheduled session" do
      session = build(:program_session, status: :scheduled)
      assert ProgramSession.can_start?(session)
    end

    test "returns false for non-scheduled sessions" do
      refute ProgramSession.can_start?(build(:program_session, status: :in_progress))
      refute ProgramSession.can_start?(build(:program_session, status: :completed))
      refute ProgramSession.can_start?(build(:program_session, status: :cancelled))
    end
  end

  describe "can_complete?/1" do
    test "returns true for :in_progress session" do
      session = build(:program_session, status: :in_progress)
      assert ProgramSession.can_complete?(session)
    end

    test "returns false for non-in-progress sessions" do
      refute ProgramSession.can_complete?(build(:program_session, status: :scheduled))
      refute ProgramSession.can_complete?(build(:program_session, status: :completed))
      refute ProgramSession.can_complete?(build(:program_session, status: :cancelled))
    end
  end

  describe "has_capacity?/2" do
    test "returns true when max_capacity is 0 (unlimited)" do
      session = build(:program_session, max_capacity: 0)
      assert ProgramSession.has_capacity?(session, 100)
      assert ProgramSession.has_capacity?(session, 0)
    end

    test "returns true when current count is below max_capacity" do
      session = build(:program_session, max_capacity: 20)
      assert ProgramSession.has_capacity?(session, 0)
      assert ProgramSession.has_capacity?(session, 10)
      assert ProgramSession.has_capacity?(session, 19)
    end

    test "returns false when current count equals max_capacity" do
      session = build(:program_session, max_capacity: 20)
      refute ProgramSession.has_capacity?(session, 20)
    end

    test "returns false when current count exceeds max_capacity" do
      session = build(:program_session, max_capacity: 20)
      refute ProgramSession.has_capacity?(session, 25)
    end
  end

  describe "active?/1" do
    test "returns true for :in_progress session" do
      session = build(:program_session, status: :in_progress)
      assert ProgramSession.active?(session)
    end

    test "returns false for non-in-progress sessions" do
      refute ProgramSession.active?(build(:program_session, status: :scheduled))
      refute ProgramSession.active?(build(:program_session, status: :completed))
      refute ProgramSession.active?(build(:program_session, status: :cancelled))
    end
  end

  describe "finalized?/1" do
    test "returns true for :completed session" do
      session = build(:program_session, status: :completed)
      assert ProgramSession.finalized?(session)
    end

    test "returns true for :cancelled session" do
      session = build(:program_session, status: :cancelled)
      assert ProgramSession.finalized?(session)
    end

    test "returns false for non-finalized sessions" do
      refute ProgramSession.finalized?(build(:program_session, status: :scheduled))
      refute ProgramSession.finalized?(build(:program_session, status: :in_progress))
    end
  end
end
