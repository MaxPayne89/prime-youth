defmodule PrimeYouth.Attendance.Domain.Events.AttendanceEvents do
  @moduledoc """
  Factory for creating Attendance domain events.

  ## Events

  - `:child_checked_in` / `:child_checked_out` - Check-in/out events (marked `:critical` for billing)
  - `:attendance_submitted` - Batch submission for payroll
  - `:session_started` / `:session_completed` - Session lifecycle events

  All factories perform fail-fast validation and raise `ArgumentError` on invalid inputs.
  """

  alias PrimeYouth.Attendance.Domain.Models.{AttendanceRecord, ProgramSession}
  alias PrimeYouth.Shared.Domain.Events.DomainEvent

  # Guard helpers for validation
  defguardp is_non_empty_string(value)
            when is_binary(value) and byte_size(value) > 0

  defguardp is_non_empty_list(value)
            when is_list(value) and value != []

  @doc """
  Creates a `child_checked_in` event (marked `:critical` for billing).

  Payload includes session_id, child_id, child_name, check_in_at, check_in_by, and check_in_notes.
  """
  def child_checked_in(record, child_name, check_in_at, check_in_by, notes, opts \\ [])

  def child_checked_in(
        %AttendanceRecord{} = record,
        child_name,
        check_in_at,
        check_in_by,
        notes,
        opts
      )
      when is_non_empty_string(child_name) and is_non_empty_string(check_in_by) do
    validate_record_for_event!(record, "child_checked_in")
    validate_datetime!(check_in_at, "check_in_at")

    payload = %{
      session_id: record.session_id,
      child_id: record.child_id,
      child_name: child_name,
      check_in_at: check_in_at,
      check_in_by: check_in_by,
      check_in_notes: notes
    }

    opts = Keyword.put_new(opts, :criticality, :critical)

    DomainEvent.new(
      :child_checked_in,
      record.id,
      :attendance_record,
      payload,
      opts
    )
  end

  def child_checked_in(%AttendanceRecord{}, child_name, _, _, _, _)
      when not is_binary(child_name) or byte_size(child_name) == 0 do
    raise ArgumentError, "child_name must be a non-empty string for child_checked_in event"
  end

  def child_checked_in(%AttendanceRecord{}, _, _, check_in_by, _, _)
      when not is_binary(check_in_by) or byte_size(check_in_by) == 0 do
    raise ArgumentError, "check_in_by must be a non-empty string for child_checked_in event"
  end

  @doc """
  Creates a `child_checked_out` event (marked `:critical` for billing).

  Calculates attendance duration and includes check-in/out details in payload.
  """
  def child_checked_out(record, child_name, check_out_at, check_out_by, notes, opts \\ [])

  def child_checked_out(
        %AttendanceRecord{check_in_at: %DateTime{} = check_in_at} = record,
        child_name,
        check_out_at,
        check_out_by,
        notes,
        opts
      )
      when is_non_empty_string(child_name) and is_non_empty_string(check_out_by) do
    validate_record_for_event!(record, "child_checked_out")
    validate_datetime!(check_out_at, "check_out_at")

    duration_seconds = DateTime.diff(check_out_at, check_in_at, :second)

    payload = %{
      session_id: record.session_id,
      child_id: record.child_id,
      child_name: child_name,
      check_in_at: check_in_at,
      check_out_at: check_out_at,
      check_out_by: check_out_by,
      check_out_notes: notes,
      duration_seconds: duration_seconds
    }

    opts = Keyword.put_new(opts, :criticality, :critical)

    DomainEvent.new(
      :child_checked_out,
      record.id,
      :attendance_record,
      payload,
      opts
    )
  end

  def child_checked_out(%AttendanceRecord{check_in_at: nil}, _, _, _, _, _) do
    raise ArgumentError, "AttendanceRecord.check_in_at cannot be nil for child_checked_out event"
  end

  def child_checked_out(%AttendanceRecord{}, child_name, _, _, _, _)
      when not is_binary(child_name) or byte_size(child_name) == 0 do
    raise ArgumentError, "child_name must be a non-empty string for child_checked_out event"
  end

  def child_checked_out(%AttendanceRecord{}, _, _, check_out_by, _, _)
      when not is_binary(check_out_by) or byte_size(check_out_by) == 0 do
    raise ArgumentError, "check_out_by must be a non-empty string for child_checked_out event"
  end

  @doc """
  Creates an `attendance_submitted` event for batch payroll submission.

  Payload includes record_count and list of submitted record_ids.
  """
  def attendance_submitted(session_id, record_ids, submitted_by, submitted_at, opts \\ [])

  def attendance_submitted(session_id, record_ids, submitted_by, submitted_at, opts)
      when is_non_empty_string(session_id) and is_non_empty_list(record_ids) and
             is_non_empty_string(submitted_by) do
    validate_datetime!(submitted_at, "submitted_at")

    payload = %{
      session_id: session_id,
      record_count: length(record_ids),
      record_ids: record_ids,
      submitted_by: submitted_by,
      submitted_at: submitted_at
    }

    DomainEvent.new(
      :attendance_submitted,
      session_id,
      :program_session,
      payload,
      opts
    )
  end

  def attendance_submitted(session_id, _, _, _, _)
      when not is_binary(session_id) or byte_size(session_id) == 0 do
    raise ArgumentError, "session_id must be a non-empty string for attendance_submitted event"
  end

  def attendance_submitted(_, record_ids, _, _, _)
      when not is_list(record_ids) or record_ids == [] do
    raise ArgumentError, "record_ids must be a non-empty list for attendance_submitted event"
  end

  def attendance_submitted(_, _, submitted_by, _, _)
      when not is_binary(submitted_by) or byte_size(submitted_by) == 0 do
    raise ArgumentError, "submitted_by must be a non-empty string for attendance_submitted event"
  end

  @doc "Creates a `session_started` event for session lifecycle tracking."
  def session_started(%ProgramSession{} = session, opts \\ []) do
    validate_session_for_event!(session, "session_started")

    payload = %{
      session_id: session.id,
      program_id: session.program_id,
      session_date: session.session_date,
      start_time: session.start_time,
      end_time: session.end_time,
      max_capacity: session.max_capacity
    }

    DomainEvent.new(
      :session_started,
      session.id,
      :program_session,
      payload,
      opts
    )
  end

  @doc "Creates a `session_completed` event with final attendance_count."
  def session_completed(session, attendance_count, opts \\ [])

  def session_completed(%ProgramSession{} = session, attendance_count, opts)
      when is_integer(attendance_count) and attendance_count >= 0 do
    validate_session_for_event!(session, "session_completed")

    payload = %{
      session_id: session.id,
      program_id: session.program_id,
      session_date: session.session_date,
      attendance_count: attendance_count
    }

    DomainEvent.new(
      :session_completed,
      session.id,
      :program_session,
      payload,
      opts
    )
  end

  def session_completed(%ProgramSession{}, attendance_count, _)
      when not is_integer(attendance_count) or attendance_count < 0 do
    raise ArgumentError,
          "attendance_count must be a non-negative integer for session_completed event"
  end

  # Private validation functions

  defp validate_record_for_event!(%AttendanceRecord{id: nil}, event_name) do
    raise ArgumentError, "AttendanceRecord.id cannot be nil for #{event_name} event"
  end

  defp validate_record_for_event!(%AttendanceRecord{session_id: id}, event_name)
       when not is_binary(id) or byte_size(id) == 0 do
    raise ArgumentError,
          "AttendanceRecord.session_id must be a non-empty string for #{event_name} event"
  end

  defp validate_record_for_event!(%AttendanceRecord{child_id: id}, event_name)
       when not is_binary(id) or byte_size(id) == 0 do
    raise ArgumentError,
          "AttendanceRecord.child_id must be a non-empty string for #{event_name} event"
  end

  defp validate_record_for_event!(%AttendanceRecord{}, _event_name), do: :ok

  defp validate_session_for_event!(%ProgramSession{id: nil}, event_name) do
    raise ArgumentError, "ProgramSession.id cannot be nil for #{event_name} event"
  end

  defp validate_session_for_event!(%ProgramSession{program_id: id}, event_name)
       when not is_binary(id) or byte_size(id) == 0 do
    raise ArgumentError,
          "ProgramSession.program_id must be a non-empty string for #{event_name} event"
  end

  defp validate_session_for_event!(%ProgramSession{}, _event_name), do: :ok

  defp validate_datetime!(%DateTime{}, _field_name), do: :ok

  defp validate_datetime!(nil, field_name) do
    raise ArgumentError, "#{field_name} cannot be nil"
  end

  defp validate_datetime!(_value, field_name) do
    raise ArgumentError, "#{field_name} must be a DateTime struct"
  end
end
