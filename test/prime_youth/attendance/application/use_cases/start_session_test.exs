defmodule PrimeYouth.Attendance.Application.UseCases.StartSessionTest do
  @moduledoc """
  Integration tests for StartSession use case.

  Tests starting a scheduled session and transitioning it to in_progress.
  """

  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Attendance.Application.UseCases.StartSession
  alias PrimeYouth.Attendance.Domain.Models.ProgramSession

  describe "execute/1" do
    test "successfully starts a scheduled session" do
      session_schema = insert(:program_session_schema, status: "scheduled")

      assert {:ok, session} = StartSession.execute(session_schema.id)
      assert %ProgramSession{} = session
      assert session.id == session_schema.id
      assert session.status == :in_progress
    end

    test "returns error when session not found" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = StartSession.execute(non_existent_id)
    end

    test "returns error when starting an in_progress session" do
      session_schema = insert(:program_session_schema, status: "in_progress")

      assert {:error, message} = StartSession.execute(session_schema.id)
      assert message =~ "Cannot start session with status: in_progress"
    end

    test "returns error when starting a completed session" do
      session_schema = insert(:program_session_schema, status: "completed")

      assert {:error, message} = StartSession.execute(session_schema.id)
      assert message =~ "Cannot start session with status: completed"
    end

    test "returns error when starting a cancelled session" do
      session_schema = insert(:program_session_schema, status: "cancelled")

      assert {:error, message} = StartSession.execute(session_schema.id)
      assert message =~ "Cannot start session with status: cancelled"
    end

    test "persists status change to database" do
      session_schema = insert(:program_session_schema, status: "scheduled")

      {:ok, started_session} = StartSession.execute(session_schema.id)

      reloaded =
        PrimeYouth.Repo.get(
          PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.ProgramSessionSchema,
          session_schema.id
        )

      assert reloaded.status == "in_progress"
      assert started_session.status == :in_progress
    end
  end
end
