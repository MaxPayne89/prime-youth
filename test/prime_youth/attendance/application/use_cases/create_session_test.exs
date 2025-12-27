defmodule PrimeYouth.Attendance.Application.UseCases.CreateSessionTest do
  @moduledoc """
  Integration tests for CreateSession use case.

  Tests session creation with domain validation and persistence.
  """

  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Attendance.Application.UseCases.CreateSession
  alias PrimeYouth.Attendance.Domain.Models.ProgramSession

  describe "execute/6" do
    test "successfully creates a session with valid attributes" do
      program = insert(:program_schema)

      assert {:ok, session} =
               CreateSession.execute(
                 program.id,
                 ~D[2025-02-15],
                 ~T[09:00:00],
                 ~T[12:00:00],
                 20,
                 "Morning session"
               )

      assert %ProgramSession{} = session
      assert session.program_id == program.id
      assert session.session_date == ~D[2025-02-15]
      assert session.start_time == ~T[09:00:00]
      assert session.end_time == ~T[12:00:00]
      assert session.max_capacity == 20
      assert session.status == :scheduled
      assert session.notes == "Morning session"
    end

    test "creates session with default nil notes when not provided" do
      program = insert(:program_schema)

      assert {:ok, session} =
               CreateSession.execute(
                 program.id,
                 ~D[2025-02-15],
                 ~T[09:00:00],
                 ~T[12:00:00],
                 20
               )

      assert session.notes == nil
    end

    test "creates session with unlimited capacity when max_capacity is 0" do
      program = insert(:program_schema)

      assert {:ok, session} =
               CreateSession.execute(
                 program.id,
                 ~D[2025-02-15],
                 ~T[09:00:00],
                 ~T[12:00:00],
                 0
               )

      assert session.max_capacity == 0
    end

    test "returns error when end_time is before start_time" do
      program = insert(:program_schema)

      assert {:error, errors} =
               CreateSession.execute(
                 program.id,
                 ~D[2025-02-15],
                 ~T[14:00:00],
                 ~T[09:00:00],
                 20
               )

      assert is_list(errors)
      assert "End time must be after start time" in errors
    end

    test "returns error when max_capacity is negative" do
      program = insert(:program_schema)

      assert {:error, errors} =
               CreateSession.execute(
                 program.id,
                 ~D[2025-02-15],
                 ~T[09:00:00],
                 ~T[12:00:00],
                 -5
               )

      assert is_list(errors)
      assert "Max capacity cannot be negative" in errors
    end

    test "returns error for duplicate session" do
      program = insert(:program_schema)
      session_date = ~D[2025-02-15]
      start_time = ~T[09:00:00]

      assert {:ok, _first} =
               CreateSession.execute(
                 program.id,
                 session_date,
                 start_time,
                 ~T[12:00:00],
                 20
               )

      assert {:error, :duplicate_session} =
               CreateSession.execute(
                 program.id,
                 session_date,
                 start_time,
                 ~T[13:00:00],
                 15
               )
    end

    test "allows sessions with different dates for same program" do
      program = insert(:program_schema)

      assert {:ok, _session1} =
               CreateSession.execute(
                 program.id,
                 ~D[2025-02-15],
                 ~T[09:00:00],
                 ~T[12:00:00],
                 20
               )

      assert {:ok, session2} =
               CreateSession.execute(
                 program.id,
                 ~D[2025-02-16],
                 ~T[09:00:00],
                 ~T[12:00:00],
                 20
               )

      assert session2.session_date == ~D[2025-02-16]
    end

    test "allows sessions with different start times on same date" do
      program = insert(:program_schema)

      assert {:ok, _session1} =
               CreateSession.execute(
                 program.id,
                 ~D[2025-02-15],
                 ~T[09:00:00],
                 ~T[12:00:00],
                 20
               )

      assert {:ok, session2} =
               CreateSession.execute(
                 program.id,
                 ~D[2025-02-15],
                 ~T[14:00:00],
                 ~T[17:00:00],
                 20
               )

      assert session2.start_time == ~T[14:00:00]
    end
  end
end
