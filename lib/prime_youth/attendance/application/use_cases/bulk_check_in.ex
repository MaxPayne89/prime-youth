defmodule PrimeYouth.Attendance.Application.UseCases.BulkCheckIn do
  @moduledoc """
  Bulk check-in multiple children for a session (atomic operation).

  ## Architecture
  - Application Layer: Coordinates bulk check-in logic
  - Domain Layer: AttendanceRecord.check_in/4 enforces business rules for each record
  - Adapter Layer: Uses Ecto.Multi for atomic batch updates

  ## Business Rules
  - All records must be in `:expected` status
  - Cannot modify submitted records (immutable)
  - Check-in timestamp auto-generated for all records
  - Batch operation is atomic (all succeed or all fail)

  ## Atomicity
  - Uses Ecto.Multi for transactional batch updates
  - If any record fails validation or update, entire batch is rolled back
  - No partial check-ins

  ## Events
  - Publishes individual `:child_checked_in` event for each checked-in child
  - Events published after successful transaction commit
  """

  alias Ecto.Multi
  alias PrimeYouth.Attendance.Domain.Events.AttendanceEvents
  alias PrimeYouth.Attendance.Domain.Models.AttendanceRecord
  alias PrimeYouth.Attendance.EventPublisher
  alias PrimeYouth.Repo

  require Logger

  @doc """
  Bulk check-in multiple children for a session.

  ## Parameters
  - `session_id` - Binary UUID of the session
  - `record_ids` - Non-empty list of binary UUIDs for records to check in
  - `provider_id` - Binary UUID of the provider performing check-in
  - `check_in_notes` - Optional notes for all check-ins (defaults to nil)

  ## Returns
  - `{:ok, [record]}` - All records successfully checked in
  - `{:error, reason}` - Check-in failed
    - `:empty_record_ids` - record_ids list is empty
    - Validation errors from domain model (invalid status, already checked in)
    - Transaction rollback errors
    - Database errors

  ## Examples

      iex> BulkCheckIn.execute(session_id, [record_id1, record_id2], provider_id)
      {:ok, [%AttendanceRecord{status: :checked_in}, ...]}

      iex> BulkCheckIn.execute(session_id, [], provider_id)
      {:error, :empty_record_ids}
  """
  def execute(session_id, record_ids, provider_id, check_in_notes \\ nil)
      when is_binary(session_id) and is_list(record_ids) and is_binary(provider_id) do
    check_in_at = DateTime.utc_now()

    with :ok <- validate_non_empty(record_ids),
         {:ok, records} <- attendance_repository().get_many_by_ids(record_ids),
         :ok <- validate_all_found(record_ids, records),
         {:ok, checked_in_records} <-
           check_in_batch(records, check_in_at, check_in_notes, provider_id) do
      publish_check_in_events(checked_in_records, check_in_at, provider_id, check_in_notes)
      {:ok, checked_in_records}
    end
  end

  # Validate record_ids is non-empty
  defp validate_non_empty([]), do: {:error, :empty_record_ids}
  defp validate_non_empty(_record_ids), do: :ok

  # Validate all requested records were found
  defp validate_all_found(record_ids, records) do
    if length(records) == length(record_ids) do
      :ok
    else
      {:error, :not_found}
    end
  end

  # Check in all records in a single atomic transaction
  defp check_in_batch(records, check_in_at, check_in_notes, provider_id) do
    multi =
      records
      |> Enum.with_index()
      |> Enum.reduce(Multi.new(), fn {record, index}, multi ->
        Multi.run(multi, {:check_in, index}, fn _repo, _changes ->
          # Apply domain logic to check in the record
          case AttendanceRecord.check_in(record, check_in_at, check_in_notes, provider_id) do
            {:ok, checked_in_record} ->
              # Persist the checked-in record via repository
              attendance_repository().update(checked_in_record)

            {:error, reason} ->
              {:error, reason}
          end
        end)
      end)

    try do
      case Repo.transaction(multi) do
        {:ok, results} ->
          # Extract checked-in records from transaction results
          checked_in_records =
            results
            |> Map.values()
            |> Enum.filter(&is_struct(&1, AttendanceRecord))

          Logger.info(
            "[BulkCheckIn] Successfully checked in batch",
            record_count: length(checked_in_records)
          )

          {:ok, checked_in_records}

        {:error, failed_operation, failed_value, _changes_so_far} ->
          Logger.error(
            "[BulkCheckIn] Transaction failed",
            failed_operation: failed_operation,
            reason: inspect(failed_value)
          )

          {:error, failed_value}
      end
    rescue
      e ->
        Logger.error(
          "[BulkCheckIn] Unexpected error during transaction",
          error: inspect(e)
        )

        {:error, :transaction_failed}
    end
  end

  # Publish individual check-in events for each checked-in child
  defp publish_check_in_events(records, check_in_at, provider_id, notes) do
    Enum.each(records, fn record ->
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
    end)
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
          "[BulkCheckIn] Failed to resolve child name, using fallback",
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
