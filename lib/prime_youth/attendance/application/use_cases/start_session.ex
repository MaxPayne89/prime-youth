defmodule PrimeYouth.Attendance.Application.UseCases.StartSession do
  @moduledoc """
  Starts a scheduled program session, transitioning it to in_progress.

  ## Architecture
  - Application Layer: Orchestrates domain logic and infrastructure
  - Domain Layer: ProgramSession.start_session/1 enforces status transitions
  - Adapter Layer: SessionRepository handles persistence

  ## Business Rules
  - Only sessions with status :scheduled can be started
  - Transitions session to :in_progress status

  ## Events
  - Publishes :session_started event on successful start
  """

  alias PrimeYouth.Attendance.Domain.Events.AttendanceEvents
  alias PrimeYouth.Attendance.Domain.Models.ProgramSession
  alias PrimeYouth.Attendance.EventPublisher

  require Logger

  @doc """
  Starts a scheduled session.

  ## Parameters
  - `session_id` - Binary UUID of the session to start

  ## Returns
  - `{:ok, session}` - Successfully started session
  - `{:error, reason}` - Start failed
    - `:not_found` - Session does not exist
    - String message from domain if session cannot be started (wrong status)
    - Database errors
  """
  def execute(session_id) when is_binary(session_id) do
    with {:ok, session} <- session_repository().get_by_id(session_id),
         {:ok, started_session} <- ProgramSession.start_session(session),
         {:ok, persisted_session} <- session_repository().update(started_session) do
      publish_session_started_event(persisted_session)
      {:ok, persisted_session}
    end
  end

  defp publish_session_started_event(session) do
    event = AttendanceEvents.session_started(session)
    EventPublisher.publish(event)
  end

  defp session_repository do
    Application.get_env(:prime_youth, :attendance)[:session_repository]
  end
end
