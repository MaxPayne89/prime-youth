defmodule PrimeYouth.Attendance.Application.UseCases.RecordCheckIn do
  @moduledoc """
  Records a child check-in for a session with timestamp and notes.

  ## Architecture
  - Application Layer: Orchestrates atomic persistence and event publishing
  - Adapter Layer: AttendanceRepository.check_in_atomic handles atomic upsert

  ## Behavior
  - Uses atomic upsert pattern for race-condition-free check-in
  - Idempotent: returns success with existing record if already checked in
  - Check-in timestamp auto-generated at call time

  ## Events
  - Publishes `:child_checked_in` event (marked `:critical` for billing impact)
  """

  alias PrimeYouth.Attendance.Domain.Events.AttendanceEvents
  alias PrimeYouth.Attendance.EventPublisher

  require Logger

  @doc """
  Records a child check-in to a session.

  Uses atomic upsert to prevent race conditions. If the child is already
  checked in, returns success with the existing record (idempotent).

  ## Parameters
  - `session_id` - Binary UUID of the session
  - `child_id` - Binary UUID of the child
  - `provider_id` - Binary UUID of the provider performing check-in
  - `check_in_notes` - Optional notes about the check-in (defaults to nil)

  ## Returns
  - `{:ok, record}` - Successfully checked in (or already checked in)
  - `{:error, reason}` - Check-in failed (database errors)

  ## Examples

      iex> RecordCheckIn.execute(session_id, child_id, provider_id, "Child arrived happy")
      {:ok, %AttendanceRecord{status: :checked_in}}

      iex> RecordCheckIn.execute(session_id, child_id, provider_id)
      {:ok, %AttendanceRecord{status: :checked_in, check_in_notes: nil}}
  """
  def execute(session_id, child_id, provider_id, check_in_notes \\ nil) do
    check_in_at = DateTime.utc_now()

    case attendance_repository().check_in_atomic(
           session_id,
           child_id,
           provider_id,
           check_in_notes
         ) do
      {:ok, record} ->
        publish_check_in_event(record, check_in_at, provider_id, check_in_notes)
        {:ok, record}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Publish child_checked_in event
  defp publish_check_in_event(record, check_in_at, provider_id, notes) do
    child_name = resolve_child_name(record.child_id)

    event =
      AttendanceEvents.child_checked_in(
        record,
        child_name,
        check_in_at,
        provider_id,
        notes || ""
      )

    EventPublisher.publish(event)
  end

  # Dependency injection: fetch repository from application config
  defp attendance_repository do
    Application.get_env(:prime_youth, :attendance)[:attendance_repository]
  end

  # Resolve child name via port adapter with graceful fallback
  defp resolve_child_name(child_id) do
    case child_name_resolver().resolve_child_name(child_id) do
      {:ok, child_name} ->
        child_name

      {:error, reason} ->
        Logger.warning(
          "[RecordCheckIn] Failed to resolve child name, using fallback",
          child_id: child_id,
          reason: reason
        )

        "Unknown Child"
    end
  end

  # Dependency injection: fetch child name resolver from application config
  defp child_name_resolver do
    Application.get_env(:prime_youth, :attendance)[:child_name_resolver]
  end
end
