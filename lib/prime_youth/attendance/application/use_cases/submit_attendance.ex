defmodule PrimeYouth.Attendance.Application.UseCases.SubmitAttendance do
  @moduledoc """
  Submits a batch of attendance records for payroll processing (atomic operation).

  ## Architecture
  - Application Layer: Coordinates batch submission logic
  - Domain Layer: AttendanceRecord.submit/3 validates submission eligibility
  - Adapter Layer: AttendanceRepository.submit_batch/3 uses Ecto.Multi for atomicity

  ## Business Rules
  - All records must be in submittable status (`:checked_out`, `:absent`, or `:excused`)
  - Records cannot already be submitted (immutable once submitted)
  - Batch operation is atomic (all succeed or all fail)

  ## Atomicity
  - Uses Ecto.Multi for transactional batch updates
  - If any record fails validation or update, entire batch is rolled back
  - No partial submissions

  ## Events
  - Publishes single `:attendance_submitted` event for entire batch
  - Event includes total record count and list of record IDs
  """

  alias PrimeYouth.Attendance.Domain.Events.AttendanceEvents
  alias PrimeYouth.Attendance.EventPublisher

  @doc """
  Submits a batch of attendance records for payroll processing.

  ## Parameters
  - `session_id` - Binary UUID of the session (for validation/grouping)
  - `record_ids` - Non-empty list of binary UUIDs for records to submit
  - `submitted_by` - Binary UUID of the provider/admin performing submission

  ## Returns
  - `{:ok, [record]}` - All records successfully submitted
  - `{:error, reason}` - Submission failed
    - `:empty_record_ids` - record_ids list is empty
    - Validation errors from domain model (invalid status, already submitted)
    - Transaction rollback errors
    - Database errors

  ## Examples

      iex> SubmitAttendance.execute(session_id, [record_id1, record_id2], provider_id)
      {:ok, [%AttendanceRecord{submitted: true}, ...]}

      iex> SubmitAttendance.execute(session_id, [], provider_id)
      {:error, :empty_record_ids}
  """
  def execute(session_id, record_ids, submitted_by) when is_list(record_ids) do
    submitted_at = DateTime.utc_now()

    with :ok <- validate_non_empty(record_ids),
         {:ok, submitted_records} <-
           attendance_repository().submit_batch(session_id, record_ids, %{
             submitted_at: submitted_at,
             submitted_by: submitted_by
           }) do
      publish_submission_event(session_id, submitted_records, submitted_by, submitted_at)
      {:ok, submitted_records}
    end
  end

  # Validate record_ids is non-empty
  defp validate_non_empty([]), do: {:error, :empty_record_ids}
  defp validate_non_empty(_record_ids), do: :ok

  # Publish attendance_submitted event for the batch
  defp publish_submission_event(session_id, records, submitted_by, submitted_at) do
    record_ids = Enum.map(records, & &1.id)
    record_count = length(records)

    event =
      AttendanceEvents.attendance_submitted(
        session_id,
        record_ids,
        record_count,
        submitted_by,
        submitted_at
      )

    EventPublisher.publish(event)
  end

  # Dependency injection: fetch repository from application config
  defp attendance_repository do
    Application.get_env(:prime_youth, :attendance)[:attendance_repository]
  end
end
