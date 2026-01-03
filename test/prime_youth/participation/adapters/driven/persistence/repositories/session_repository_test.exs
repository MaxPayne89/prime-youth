defmodule KlassHero.Participation.Adapters.Driven.Persistence.Repositories.SessionRepositoryTest do
  @moduledoc """
  Integration tests for SessionRepository.

  Tests database operations for program session persistence including
  creation, retrieval, updates, and query operations.
  """

  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Participation.Adapters.Driven.Persistence.Mappers.ProgramSessionMapper
  alias KlassHero.Participation.Adapters.Driven.Persistence.Repositories.SessionRepository
  alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.ProgramSessionSchema
  alias KlassHero.Participation.Domain.Models.ProgramSession
  alias KlassHero.Repo

  describe "create/1" do
    test "successfully creates a session and returns domain entity" do
      program = insert(:program_schema)

      session = build(:program_session, program_id: program.id)

      assert {:ok, created} = SessionRepository.create(session)
      assert %ProgramSession{} = created
      assert created.program_id == program.id
      assert created.session_date == session.session_date
      assert created.start_time == session.start_time
      assert created.end_time == session.end_time
      assert created.max_capacity == session.max_capacity
      assert created.status == :scheduled
    end

    test "returns error for duplicate session" do
      program = insert(:program_schema)
      session_date = ~D[2025-02-15]
      start_time = ~T[09:00:00]

      # Insert first session
      first_session =
        build(:program_session,
          program_id: program.id,
          session_date: session_date,
          start_time: start_time
        )

      assert {:ok, _created} = SessionRepository.create(first_session)

      # Attempt duplicate
      duplicate_session =
        build(:program_session,
          program_id: program.id,
          session_date: session_date,
          start_time: start_time
        )

      assert {:error, :duplicate_session} = SessionRepository.create(duplicate_session)
    end

    test "allows sessions with different dates for same program" do
      program = insert(:program_schema)

      session1 =
        build(:program_session,
          program_id: program.id,
          session_date: ~D[2025-02-15]
        )

      session2 =
        build(:program_session,
          program_id: program.id,
          session_date: ~D[2025-02-16]
        )

      assert {:ok, _} = SessionRepository.create(session1)
      assert {:ok, _} = SessionRepository.create(session2)
    end

    test "allows sessions with different start times on same date" do
      program = insert(:program_schema)

      session1 =
        build(:program_session,
          program_id: program.id,
          session_date: ~D[2025-02-15],
          start_time: ~T[09:00:00]
        )

      session2 =
        build(:program_session,
          program_id: program.id,
          session_date: ~D[2025-02-15],
          start_time: ~T[14:00:00],
          end_time: ~T[17:00:00]
        )

      assert {:ok, _} = SessionRepository.create(session1)
      assert {:ok, _} = SessionRepository.create(session2)
    end
  end

  describe "get_by_id/1" do
    test "returns session when found" do
      session_schema = insert(:program_session_schema)

      assert {:ok, session} = SessionRepository.get_by_id(session_schema.id)
      assert %ProgramSession{} = session
      assert session.id == session_schema.id
      assert session.program_id == session_schema.program_id
    end

    test "returns error when session not found" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = SessionRepository.get_by_id(non_existent_id)
    end
  end

  describe "update/1" do
    test "successfully updates session status" do
      session_schema = insert(:program_session_schema)
      domain_session = ProgramSessionMapper.to_domain(session_schema)

      # Start session (transition from :scheduled to :in_progress)
      {:ok, started} = ProgramSession.start(domain_session)

      assert {:ok, updated} = SessionRepository.update(started)
      assert updated.status == :in_progress
    end

    test "returns error when session not found" do
      non_existent_session = build(:program_session, id: Ecto.UUID.generate())

      assert {:error, :not_found} = SessionRepository.update(non_existent_session)
    end

    test "updates session notes" do
      session_schema = insert(:program_session_schema, notes: nil)
      domain_session = ProgramSessionMapper.to_domain(session_schema)

      updated_session = %{domain_session | notes: "Special equipment required"}

      assert {:ok, result} = SessionRepository.update(updated_session)
      assert result.notes == "Special equipment required"
    end

    test "persists max_capacity changes" do
      session_schema = insert(:program_session_schema, max_capacity: 20)
      domain_session = ProgramSessionMapper.to_domain(session_schema)

      updated_session = %{domain_session | max_capacity: 25}

      assert {:ok, result} = SessionRepository.update(updated_session)
      assert result.max_capacity == 25

      # Verify in database
      reloaded = Repo.get(ProgramSessionSchema, session_schema.id)
      assert reloaded.max_capacity == 25
    end
  end

  describe "list_by_program/1" do
    test "returns sessions ordered by date and time" do
      program = insert(:program_schema)

      # Insert in non-sequential order
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

      sessions = SessionRepository.list_by_program(program.id)
      assert length(sessions) == 4

      dates = Enum.map(sessions, & &1.session_date)
      assert dates == [~D[2025-02-15], ~D[2025-02-16], ~D[2025-02-16], ~D[2025-02-17]]

      # Check time ordering for same-day sessions
      same_day_sessions = Enum.filter(sessions, &(&1.session_date == ~D[2025-02-16]))
      times = Enum.map(same_day_sessions, & &1.start_time)
      assert times == [~T[09:00:00], ~T[14:00:00]]
    end

    test "returns empty list when program has no sessions" do
      program = insert(:program_schema)

      assert [] = SessionRepository.list_by_program(program.id)
    end

    test "does not return sessions from other programs" do
      program1 = insert(:program_schema)
      program2 = insert(:program_schema)

      insert(:program_session_schema, program_id: program1.id)
      insert(:program_session_schema, program_id: program2.id)

      sessions = SessionRepository.list_by_program(program1.id)
      assert length(sessions) == 1
      assert Enum.all?(sessions, &(&1.program_id == program1.id))
    end
  end

  describe "list_today_sessions/1" do
    test "returns sessions for specified date" do
      program = insert(:program_schema)
      target_date = ~D[2025-02-15]

      insert(:program_session_schema,
        program_id: program.id,
        session_date: target_date,
        start_time: ~T[09:00:00]
      )

      insert(:program_session_schema,
        program_id: program.id,
        session_date: target_date,
        start_time: ~T[10:00:00]
      )

      insert(:program_session_schema, program_id: program.id, session_date: ~D[2025-02-16])

      sessions = SessionRepository.list_today_sessions(target_date)
      assert length(sessions) == 2
      assert Enum.all?(sessions, &(&1.session_date == target_date))
    end

    test "returns sessions ordered by start time" do
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

      sessions = SessionRepository.list_today_sessions(target_date)
      times = Enum.map(sessions, & &1.start_time)
      assert times == [~T[09:00:00], ~T[14:00:00]]
    end

    test "returns empty list when no sessions for date" do
      target_date = ~D[2025-02-15]

      assert [] = SessionRepository.list_today_sessions(target_date)
    end
  end

  describe "list_by_provider_and_date/2" do
    test "returns sessions for specified date" do
      program = insert(:program_schema)
      provider_id = Ecto.UUID.generate()
      target_date = ~D[2025-02-15]

      insert(:program_session_schema, program_id: program.id, session_date: target_date)
      insert(:program_session_schema, program_id: program.id, session_date: ~D[2025-02-16])

      sessions = SessionRepository.list_by_provider_and_date(provider_id, target_date)

      assert length(sessions) == 1
      assert Enum.all?(sessions, &(&1.session_date == target_date))
    end

    test "returns sessions ordered by start time" do
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

      sessions = SessionRepository.list_by_provider_and_date(provider_id, target_date)

      times = Enum.map(sessions, & &1.start_time)
      assert times == [~T[10:00:00], ~T[16:00:00]]
    end

    test "returns empty list when no sessions for date" do
      provider_id = Ecto.UUID.generate()
      target_date = ~D[2025-02-15]

      assert [] = SessionRepository.list_by_provider_and_date(provider_id, target_date)
    end
  end
end
