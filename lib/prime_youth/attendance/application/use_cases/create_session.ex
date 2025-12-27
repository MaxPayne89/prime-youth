defmodule PrimeYouth.Attendance.Application.UseCases.CreateSession do
  @moduledoc """
  Creates a new program session with domain validation and event publishing.

  ## Architecture
  - Application Layer: Orchestrates domain logic and infrastructure
  - Domain Layer: ProgramSession enforces business rules (end_time > start_time, max_capacity >= 0)
  - Adapter Layer: SessionRepository handles persistence

  ## Business Rules
  - max_capacity >= 0 (0 means unlimited capacity)
  - end_time must be after start_time
  - Unique constraint: one session per program/date/start_time combination

  ## Events
  - Publishes `:session_started` event on successful creation
  """

  alias PrimeYouth.Attendance.Domain.Events.AttendanceEvents
  alias PrimeYouth.Attendance.Domain.Models.ProgramSession
  alias PrimeYouth.Attendance.EventPublisher

  @doc """
  Creates a new program session.

  ## Parameters
  - `program_id` - Binary UUID of the program
  - `session_date` - Date of the session
  - `start_time` - Session start time
  - `end_time` - Session end time (must be after start_time)
  - `max_capacity` - Maximum number of children (0 = unlimited)
  - `notes` - Optional notes about the session (defaults to nil)

  ## Returns
  - `{:ok, session}` - Successfully created session
  - `{:error, reason}` - Creation failed
    - Validation errors from domain model
    - `:duplicate_session` - Session already exists for this program/date/time
    - Database errors (`:database_connection_error`, etc.)

  ## Examples

      iex> CreateSession.execute(
      ...>   program_id,
      ...>   ~D[2025-01-15],
      ...>   ~T[09:00:00],
      ...>   ~T[12:00:00],
      ...>   20,
      ...>   "Morning session"
      ...> )
      {:ok, %ProgramSession{}}

      iex> CreateSession.execute(
      ...>   program_id,
      ...>   ~D[2025-01-15],
      ...>   ~T[12:00:00],
      ...>   ~T[09:00:00],  # Invalid: end before start
      ...>   20
      ...> )
      {:error, [:end_time_must_be_after_start_time]}
  """
  def execute(program_id, session_date, start_time, end_time, max_capacity, notes \\ nil) do
    session_id = Ecto.UUID.generate()

    attrs = %{
      id: session_id,
      program_id: program_id,
      session_date: session_date,
      start_time: start_time,
      end_time: end_time,
      max_capacity: max_capacity,
      status: :scheduled,
      notes: notes
    }

    with {:ok, session} <- ProgramSession.new(attrs),
         {:ok, persisted_session} <- session_repository().create(session) do
      publish_session_started_event(persisted_session)
      {:ok, persisted_session}
    end
  end

  # Publish session_started event
  defp publish_session_started_event(session) do
    event = AttendanceEvents.session_started(session)
    EventPublisher.publish(event)
  end

  # Dependency injection: fetch repository from application config
  defp session_repository do
    Application.get_env(:prime_youth, :attendance)[:session_repository]
  end
end
