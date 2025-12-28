defmodule PrimeYouth.Attendance.Application.UseCases.ListSessionsTest do
  @moduledoc """
  Integration tests for ListSessions use case.

  Tests listing sessions with different filter types.
  """

  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Attendance.Application.UseCases.ListSessions
  alias PrimeYouth.Attendance.Domain.Models.ProgramSession

  describe "execute/2 with :by_program filter" do
    test "returns sessions for a program ordered by date and time" do
      program = insert(:program_schema)

      insert(:program_session_schema,
        program_id: program.id,
        session_date: ~D[2025-02-17],
        start_time: ~T[09:00:00]
      )

      insert(:program_session_schema,
        program_id: program.id,
        session_date: ~D[2025-02-15],
        start_time: ~T[09:00:00]
      )

      insert(:program_session_schema,
        program_id: program.id,
        session_date: ~D[2025-02-16],
        start_time: ~T[14:00:00],
        end_time: ~T[17:00:00]
      )

      insert(:program_session_schema,
        program_id: program.id,
        session_date: ~D[2025-02-16],
        start_time: ~T[09:00:00]
      )

      sessions = ListSessions.execute(:by_program, program.id)
      assert length(sessions) == 4
      assert Enum.all?(sessions, &match?(%ProgramSession{}, &1))

      dates = Enum.map(sessions, & &1.session_date)
      assert dates == [~D[2025-02-15], ~D[2025-02-16], ~D[2025-02-16], ~D[2025-02-17]]

      same_day_sessions = Enum.filter(sessions, &(&1.session_date == ~D[2025-02-16]))
      times = Enum.map(same_day_sessions, & &1.start_time)
      assert times == [~T[09:00:00], ~T[14:00:00]]
    end

    test "returns empty list when program has no sessions" do
      program = insert(:program_schema)

      sessions = ListSessions.execute(:by_program, program.id)
      assert sessions == []
    end

    test "does not return sessions from other programs" do
      program1 = insert(:program_schema)
      program2 = insert(:program_schema)

      insert(:program_session_schema, program_id: program1.id)
      insert(:program_session_schema, program_id: program2.id)

      sessions = ListSessions.execute(:by_program, program1.id)
      assert length(sessions) == 1
      assert Enum.all?(sessions, &(&1.program_id == program1.id))
    end
  end

  describe "execute/2 with :today filter" do
    test "returns sessions for a specific date ordered by time" do
      program = insert(:program_schema)
      target_date = ~D[2025-02-15]

      insert(:program_session_schema,
        program_id: program.id,
        session_date: target_date,
        start_time: ~T[14:00:00],
        end_time: ~T[17:00:00]
      )

      insert(:program_session_schema,
        program_id: program.id,
        session_date: target_date,
        start_time: ~T[09:00:00]
      )

      insert(:program_session_schema,
        program_id: program.id,
        session_date: ~D[2025-02-16],
        start_time: ~T[09:00:00]
      )

      sessions = ListSessions.execute(:today, target_date)
      assert length(sessions) == 2
      assert Enum.all?(sessions, &(&1.session_date == target_date))

      times = Enum.map(sessions, & &1.start_time)
      assert times == [~T[09:00:00], ~T[14:00:00]]
    end

    test "returns empty list when no sessions for date" do
      target_date = ~D[2025-02-15]

      sessions = ListSessions.execute(:today, target_date)
      assert sessions == []
    end
  end

  describe "execute/2 with invalid filter" do
    test "returns error for invalid filter type" do
      assert {:error, {:invalid_filter_type, :unknown_filter}} =
               ListSessions.execute(:unknown_filter, "some_value")
    end
  end
end
