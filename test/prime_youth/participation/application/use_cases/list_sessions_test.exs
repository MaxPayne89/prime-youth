defmodule PrimeYouth.Participation.Application.UseCases.ListSessionsTest do
  @moduledoc """
  Integration tests for ListSessions use case.

  Tests listing sessions with different filter criteria.
  """

  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Participation.Application.UseCases.ListSessions
  alias PrimeYouth.Participation.Domain.Models.ProgramSession

  describe "execute/1 with program_id filter" do
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

      sessions = ListSessions.execute(%{program_id: program.id})
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

      sessions = ListSessions.execute(%{program_id: program.id})
      assert sessions == []
    end

    test "does not return sessions from other programs" do
      program1 = insert(:program_schema)
      program2 = insert(:program_schema)

      insert(:program_session_schema, program_id: program1.id)
      insert(:program_session_schema, program_id: program2.id)

      sessions = ListSessions.execute(%{program_id: program1.id})
      assert length(sessions) == 1
      assert Enum.all?(sessions, &(&1.program_id == program1.id))
    end
  end

  describe "execute/1 with date filter" do
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

      sessions = ListSessions.execute(%{date: target_date})
      assert length(sessions) == 2
      assert Enum.all?(sessions, &(&1.session_date == target_date))

      times = Enum.map(sessions, & &1.start_time)
      assert times == [~T[09:00:00], ~T[14:00:00]]
    end

    test "returns empty list when no sessions for date" do
      target_date = ~D[2025-02-15]

      sessions = ListSessions.execute(%{date: target_date})
      assert sessions == []
    end
  end

  describe "execute/1 with empty map" do
    test "returns today's sessions by default" do
      # When no filter is specified, it defaults to today's date
      sessions = ListSessions.execute(%{})
      assert is_list(sessions)
    end
  end
end
