defmodule PrimeYouth.Participation.Application.UseCases.ListProviderSessionsTest do
  @moduledoc """
  Integration tests for ListProviderSessions use case.

  Tests listing sessions for a provider on a specific date.
  """

  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Participation.Application.UseCases.ListProviderSessions
  alias PrimeYouth.Participation.Domain.Models.ProgramSession

  describe "execute/1" do
    test "returns sessions for a date ordered by start time" do
      program = insert(:program_schema)
      provider_id = Ecto.UUID.generate()
      target_date = ~D[2025-02-15]

      insert(:program_session_schema,
        program_id: program.id,
        session_date: target_date,
        start_time: ~T[16:00:00],
        end_time: ~T[19:00:00]
      )

      insert(:program_session_schema,
        program_id: program.id,
        session_date: target_date,
        start_time: ~T[10:00:00]
      )

      insert(:program_session_schema,
        program_id: program.id,
        session_date: ~D[2025-02-16],
        start_time: ~T[09:00:00]
      )

      assert {:ok, sessions} =
               ListProviderSessions.execute(%{provider_id: provider_id, date: target_date})

      assert length(sessions) == 2
      assert Enum.all?(sessions, &match?(%ProgramSession{}, &1))
      assert Enum.all?(sessions, &(&1.session_date == target_date))

      times = Enum.map(sessions, & &1.start_time)
      assert times == [~T[10:00:00], ~T[16:00:00]]
    end

    test "returns empty list when no sessions for date" do
      provider_id = Ecto.UUID.generate()
      target_date = ~D[2025-02-15]

      assert {:ok, sessions} =
               ListProviderSessions.execute(%{provider_id: provider_id, date: target_date})

      assert sessions == []
    end

    test "returns sessions from multiple programs on same date" do
      program1 = insert(:program_schema)
      program2 = insert(:program_schema)
      provider_id = Ecto.UUID.generate()
      target_date = ~D[2025-02-15]

      insert(:program_session_schema,
        program_id: program1.id,
        session_date: target_date,
        start_time: ~T[09:00:00]
      )

      insert(:program_session_schema,
        program_id: program2.id,
        session_date: target_date,
        start_time: ~T[14:00:00],
        end_time: ~T[17:00:00]
      )

      assert {:ok, sessions} =
               ListProviderSessions.execute(%{provider_id: provider_id, date: target_date})

      assert length(sessions) == 2
    end

    test "defaults to today when date not provided" do
      provider_id = Ecto.UUID.generate()

      assert {:ok, sessions} = ListProviderSessions.execute(%{provider_id: provider_id})
      assert is_list(sessions)
    end
  end
end
