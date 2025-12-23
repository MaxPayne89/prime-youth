defmodule PrimeYouth.Attendance.Application.UseCases.RecordCheckIn do
  @moduledoc """
  Records a child check-in for a session with timestamp and notes.

  ## Architecture
  - Application Layer: Orchestrates domain logic and persistence
  - Domain Layer: AttendanceRecord.check_in/4 enforces business rules
  - Adapter Layer: AttendanceRepository handles persistence with optimistic locking

  ## Business Rules
  - Can only check in records with status `:expected`
  - Cannot modify submitted records (immutable)
  - Check-in timestamp auto-generated

  ## Concurrency Safety
  - Uses optimistic locking (lock_version) to handle concurrent modifications
  - Returns `:stale_data` error if record was modified by another process

  ## Events
  - Publishes `:child_checked_in` event (marked `:critical` for billing impact)
  """

  alias PrimeYouth.Attendance.Domain.Events.AttendanceEvents
  alias PrimeYouth.Attendance.Domain.Models.AttendanceRecord
  alias PrimeYouth.Attendance.EventPublisher
  alias PrimeYouth.Family.Domain.Models.Child

  require Logger

  @doc """
  Records a child check-in to a session.

  ## Parameters
  - `session_id` - Binary UUID of the session
  - `child_id` - Binary UUID of the child
  - `provider_id` - Binary UUID of the provider performing check-in
  - `check_in_notes` - Optional notes about the check-in (defaults to nil)

  ## Returns
  - `{:ok, record}` - Successfully checked in
  - `{:error, reason}` - Check-in failed
    - Domain validation errors (already checked in, submitted record, invalid status)
    - `:stale_data` - Concurrent modification detected
    - Database errors

  ## Examples

      iex> RecordCheckIn.execute(session_id, child_id, provider_id, "Child arrived happy")
      {:ok, %AttendanceRecord{status: :checked_in}}

      iex> RecordCheckIn.execute(session_id, child_id, provider_id)
      {:ok, %AttendanceRecord{status: :checked_in, check_in_notes: nil}}
  """
  def execute(session_id, child_id, provider_id, check_in_notes \\ nil) do
    check_in_at = DateTime.utc_now()

    with {:ok, record} <- fetch_or_create_record(session_id, child_id),
         {:ok, checked_in_record} <-
           AttendanceRecord.check_in(record, check_in_at, check_in_notes, provider_id),
         {:ok, persisted_record} <- persist_record(record, checked_in_record) do
      publish_check_in_event(persisted_record, check_in_at, provider_id, check_in_notes)
      {:ok, persisted_record}
    end
  end

  # Fetch existing record or create new one with :expected status
  defp fetch_or_create_record(session_id, child_id) do
    case attendance_repository().get_by_session_and_child(session_id, child_id) do
      {:ok, record} ->
        {:ok, record}

      {:error, :not_found} ->
        create_expected_record(session_id, child_id)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Create new attendance record with :expected status (in-memory only)
  defp create_expected_record(session_id, child_id) do
    record_id = Ecto.UUID.generate()

    attrs = %{
      id: record_id,
      session_id: session_id,
      child_id: child_id,
      parent_id: nil,
      provider_id: nil,
      status: :expected,
      check_in_at: nil,
      check_in_notes: nil,
      check_in_by: nil,
      check_out_at: nil,
      check_out_notes: nil,
      check_out_by: nil,
      submitted: false,
      submitted_at: nil,
      submitted_by: nil
    }

    AttendanceRecord.new(attrs)
  end

  # Persist record - create if new (no check_in_at originally), update if existing
  defp persist_record(%AttendanceRecord{check_in_at: nil}, checked_in_record) do
    # Record was newly created, use create/1
    attendance_repository().create(checked_in_record)
  end

  defp persist_record(_original_record, checked_in_record) do
    # Record already existed, use update/1 (with optimistic locking)
    attendance_repository().update(checked_in_record)
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

  # Resolve child name from Family context with graceful fallback
  defp resolve_child_name(child_id) do
    case child_repository().get_by_id(child_id) do
      {:ok, child} ->
        Child.full_name(child)

      {:error, reason} ->
        Logger.warning(
          "[RecordCheckIn] Failed to resolve child name, using fallback",
          child_id: child_id,
          reason: reason
        )

        "Unknown Child"
    end
  end

  # Dependency injection: fetch child repository from application config
  defp child_repository do
    Application.get_env(:prime_youth, :family)[:child_repository]
  end
end
