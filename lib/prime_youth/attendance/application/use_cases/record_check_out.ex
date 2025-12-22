defmodule PrimeYouth.Attendance.Application.UseCases.RecordCheckOut do
  @moduledoc """
  Records a child check-out from a session with timestamp and notes.

  ## Architecture
  - Application Layer: Orchestrates domain logic and persistence
  - Domain Layer: AttendanceRecord.check_out/4 enforces business rules
  - Adapter Layer: AttendanceRepository handles persistence with optimistic locking

  ## Business Rules
  - Can only check out records with status `:checked_in`
  - Cannot modify submitted records (immutable)
  - Check-out timestamp must be >= check-in timestamp
  - Check-out timestamp auto-generated

  ## Concurrency Safety
  - Uses optimistic locking (lock_version) to handle concurrent modifications
  - Returns `:stale_data` error if record was modified by another process

  ## Events
  - Publishes `:child_checked_out` event (marked `:critical` for billing impact)
  - Event includes calculated duration_seconds
  """

  alias PrimeYouth.Attendance.Domain.Events.AttendanceEvents
  alias PrimeYouth.Attendance.Domain.Models.AttendanceRecord
  alias PrimeYouth.Attendance.EventPublisher

  @doc """
  Records a child check-out from a session.

  ## Parameters
  - `session_id` - Binary UUID of the session
  - `child_id` - Binary UUID of the child
  - `provider_id` - Binary UUID of the provider performing check-out
  - `check_out_notes` - Optional notes about the check-out (defaults to nil)

  ## Returns
  - `{:ok, record}` - Successfully checked out
  - `{:error, reason}` - Check-out failed
    - `:not_found` - No attendance record exists for this session/child
    - Domain validation errors (not checked in, submitted record, invalid check-out time)
    - `:stale_data` - Concurrent modification detected
    - Database errors

  ## Examples

      iex> RecordCheckOut.execute(session_id, child_id, provider_id, "Child picked up by parent")
      {:ok, %AttendanceRecord{status: :checked_out}}

      iex> RecordCheckOut.execute(session_id, child_id, provider_id)
      {:ok, %AttendanceRecord{status: :checked_out, check_out_notes: nil}}
  """
  def execute(session_id, child_id, provider_id, check_out_notes \\ nil) do
    check_out_at = DateTime.utc_now()

    with {:ok, record} <- attendance_repository().get_by_session_and_child(session_id, child_id),
         {:ok, checked_out_record} <-
           AttendanceRecord.check_out(record, check_out_at, check_out_notes, provider_id),
         {:ok, persisted_record} <- attendance_repository().update(checked_out_record) do
      publish_check_out_event(persisted_record, check_out_at, provider_id, check_out_notes)
      {:ok, persisted_record}
    end
  end

  # Publish child_checked_out event with duration calculation
  defp publish_check_out_event(record, check_out_at, provider_id, notes) do
    # Stub child_name until Family Management context is implemented
    child_name = ""

    event =
      AttendanceEvents.child_checked_out(
        record,
        child_name,
        check_out_at,
        provider_id,
        notes || ""
      )

    EventPublisher.publish(event)
  end

  # Dependency injection: fetch repository from application config
  defp attendance_repository do
    Application.get_env(:prime_youth, :attendance)[:attendance_repository]
  end
end
