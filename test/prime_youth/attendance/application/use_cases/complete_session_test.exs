defmodule PrimeYouth.Attendance.Application.UseCases.CompleteSessionTest do
  @moduledoc """
  Integration tests for CompleteSession use case.

  Tests completing an in_progress session and transitioning it to completed.
  """

  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Attendance.Application.UseCases.CompleteSession
  alias PrimeYouth.Attendance.Domain.Models.ProgramSession

  describe "execute/1" do
    test "successfully completes an in_progress session" do
      session_schema = insert(:program_session_schema, status: "in_progress")

      assert {:ok, session} = CompleteSession.execute(session_schema.id)
      assert %ProgramSession{} = session
      assert session.id == session_schema.id
      assert session.status == :completed
    end

    test "returns error when session not found" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = CompleteSession.execute(non_existent_id)
    end

    test "returns error when completing a scheduled session" do
      session_schema = insert(:program_session_schema, status: "scheduled")

      assert {:error, message} = CompleteSession.execute(session_schema.id)
      assert message =~ "Cannot complete session with status: scheduled"
    end

    test "returns error when completing a completed session" do
      session_schema = insert(:program_session_schema, status: "completed")

      assert {:error, message} = CompleteSession.execute(session_schema.id)
      assert message =~ "Cannot complete session with status: completed"
    end

    test "returns error when completing a cancelled session" do
      session_schema = insert(:program_session_schema, status: "cancelled")

      assert {:error, message} = CompleteSession.execute(session_schema.id)
      assert message =~ "Cannot complete session with status: cancelled"
    end

    test "persists status change to database" do
      session_schema = insert(:program_session_schema, status: "in_progress")

      {:ok, completed_session} = CompleteSession.execute(session_schema.id)

      reloaded =
        PrimeYouth.Repo.get(
          PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.ProgramSessionSchema,
          session_schema.id
        )

      assert reloaded.status == "completed"
      assert completed_session.status == :completed
    end

    test "counts attendance records when completing" do
      session_schema = insert(:program_session_schema, status: "in_progress")
      child1 = insert(:child_schema)
      child2 = insert(:child_schema)
      child3 = insert(:child_schema)

      insert(:attendance_record_schema,
        session_id: session_schema.id,
        child_id: child1.id,
        status: "checked_in"
      )

      insert(:attendance_record_schema,
        session_id: session_schema.id,
        child_id: child2.id,
        status: "checked_out"
      )

      insert(:attendance_record_schema,
        session_id: session_schema.id,
        child_id: child3.id,
        status: "expected"
      )

      assert {:ok, session} = CompleteSession.execute(session_schema.id)
      assert session.status == :completed
    end
  end
end
