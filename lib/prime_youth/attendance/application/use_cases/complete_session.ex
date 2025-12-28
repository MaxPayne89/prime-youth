defmodule PrimeYouth.Attendance.Application.UseCases.CompleteSession do
  @moduledoc """
  Completes an in-progress program session, transitioning it to completed.

  ## Architecture
  - Application Layer: Orchestrates domain logic and infrastructure
  - Domain Layer: ProgramSession.complete_session/1 enforces status transitions
  - Adapter Layer: SessionRepository handles persistence

  ## Business Rules
  - Only sessions with status :in_progress can be completed
  - Transitions session to :completed status

  ## Events
  - Publishes :session_completed event with attendance count
  """

  alias PrimeYouth.Attendance.Domain.Events.AttendanceEvents
  alias PrimeYouth.Attendance.Domain.Models.ProgramSession
  alias PrimeYouth.Attendance.EventPublisher

  require Logger

  @doc """
  Completes an in-progress session.

  ## Parameters
  - `session_id` - Binary UUID of the session to complete

  ## Returns
  - `{:ok, session}` - Successfully completed session
  - `{:error, reason}` - Completion failed
    - `:not_found` - Session does not exist
    - String message from domain if session cannot be completed (wrong status)
    - Database errors
  """
  def execute(session_id) when is_binary(session_id) do
    with {:ok, session} <- session_repository().get_by_id(session_id),
         {:ok, completed_session} <- ProgramSession.complete_session(session),
         {:ok, persisted_session} <- session_repository().update(completed_session),
         {:ok, attendance_count} <- get_attendance_count(session_id) do
      publish_session_completed_event(persisted_session, attendance_count)
      {:ok, persisted_session}
    end
  end

  defp get_attendance_count(session_id) do
    records = attendance_repository().list_by_session(session_id)

    count =
      records
      |> Enum.count(fn record -> record.status in [:checked_in, :checked_out] end)

    {:ok, count}
  end

  defp publish_session_completed_event(session, attendance_count) do
    event = AttendanceEvents.session_completed(session, attendance_count)
    EventPublisher.publish(event)
  end

  defp session_repository do
    Application.get_env(:prime_youth, :attendance)[:session_repository]
  end

  defp attendance_repository do
    Application.get_env(:prime_youth, :attendance)[:attendance_repository]
  end
end
