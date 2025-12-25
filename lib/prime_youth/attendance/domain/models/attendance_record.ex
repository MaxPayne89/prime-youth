defmodule PrimeYouth.Attendance.Domain.Models.AttendanceRecord do
  @moduledoc """
  Pure domain entity for child attendance tracking in sessions.

  ## Status Lifecycle

  - `:expected → :checked_in → :checked_out` (normal flow)
  - `:expected → :absent` or `:excused` (non-attendance)
  - `:checked_in → :absent` (corrections only)

  Records can be submitted for payroll. Submitted records cannot be modified.
  """

  @enforce_keys [:id, :session_id, :child_id, :status]

  defstruct [
    :id,
    :session_id,
    :child_id,
    :parent_id,
    :provider_id,
    :status,
    :check_in_at,
    :check_in_notes,
    :check_in_by,
    :check_out_at,
    :check_out_notes,
    :check_out_by,
    :submitted_at,
    :submitted_by,
    :inserted_at,
    :updated_at,
    submitted: false,
    lock_version: 1
  ]

  @doc """
  Creates a new AttendanceRecord with validation.

  Business Rules: check_out_at ≥ check_in_at; submitted records require submitted_at/submitted_by.
  """
  def new(attrs) do
    record = struct!(__MODULE__, attrs)

    case validate(record) do
      [] -> {:ok, record}
      errors -> {:error, errors}
    end
  end

  @doc "Validates business rules."
  def valid?(record) do
    validate(record) == []
  end

  @doc "Transitions record from :expected to :checked_in. Cannot modify submitted records."
  def check_in(
        %__MODULE__{status: :expected, submitted: false} = record,
        check_in_at,
        check_in_notes,
        check_in_by
      ) do
    {:ok,
     %{
       record
       | status: :checked_in,
         check_in_at: check_in_at,
         check_in_notes: check_in_notes,
         check_in_by: check_in_by
     }}
  end

  def check_in(%__MODULE__{submitted: true}, _, _, _) do
    {:error, "Cannot check in a submitted record"}
  end

  def check_in(%__MODULE__{status: status}, _, _, _) do
    {:error, "Cannot check in with status: #{status}"}
  end

  @doc "Transitions record from :checked_in to :checked_out. Validates check_out_at ≥ check_in_at."
  def check_out(
        %__MODULE__{status: :checked_in, submitted: false, check_in_at: check_in_at} = record,
        check_out_at,
        check_out_notes,
        check_out_by
      ) do
    case DateTime.compare(check_out_at, check_in_at) do
      :lt ->
        {:error, "Check-out time cannot be before check-in time"}

      _ ->
        {:ok,
         %{
           record
           | status: :checked_out,
             check_out_at: check_out_at,
             check_out_notes: check_out_notes,
             check_out_by: check_out_by
         }}
    end
  end

  def check_out(%__MODULE__{submitted: true}, _, _, _) do
    {:error, "Cannot check out a submitted record"}
  end

  def check_out(%__MODULE__{status: status}, _, _, _) do
    {:error, "Cannot check out with status: #{status}"}
  end

  @doc "Marks record as :absent, clearing check-in/out data."
  def mark_absent(%__MODULE__{status: status, submitted: false} = record)
      when status in [:expected, :checked_in] do
    {:ok,
     %{
       record
       | status: :absent,
         check_in_at: nil,
         check_in_notes: nil,
         check_in_by: nil,
         check_out_at: nil,
         check_out_notes: nil,
         check_out_by: nil
     }}
  end

  def mark_absent(%__MODULE__{submitted: true}) do
    {:error, "Cannot mark a submitted record as absent"}
  end

  def mark_absent(%__MODULE__{status: status}) do
    {:error, "Cannot mark as absent with status: #{status}"}
  end

  @doc "Marks record as :excused, clearing check-in/out data."
  def mark_excused(%__MODULE__{status: status, submitted: false} = record)
      when status in [:expected, :checked_in] do
    {:ok,
     %{
       record
       | status: :excused,
         check_in_at: nil,
         check_in_notes: nil,
         check_in_by: nil,
         check_out_at: nil,
         check_out_notes: nil,
         check_out_by: nil
     }}
  end

  def mark_excused(%__MODULE__{submitted: true}) do
    {:error, "Cannot mark a submitted record as excused"}
  end

  def mark_excused(%__MODULE__{status: status}) do
    {:error, "Cannot mark as excused with status: #{status}"}
  end

  @doc "Submits record for payroll. Only :checked_out, :absent, or :excused records can be submitted."
  def submit(%__MODULE__{status: status} = record, submitted_at, submitted_by)
      when status in [:checked_out, :absent, :excused] do
    {:ok, %{record | submitted: true, submitted_at: submitted_at, submitted_by: submitted_by}}
  end

  def submit(%__MODULE__{status: status}, _, _) do
    {:error, "Cannot submit record with status: #{status}"}
  end

  @doc "Removes submission flags to allow corrections. Preserves check-in/out data."
  def unsubmit(%__MODULE__{} = record) do
    {:ok, %{record | submitted: false, submitted_at: nil, submitted_by: nil}}
  end

  def checked_in?(%__MODULE__{status: status}) when status in [:checked_in, :checked_out],
    do: true

  def checked_in?(_), do: false

  def checked_out?(%__MODULE__{status: :checked_out}), do: true
  def checked_out?(_), do: false

  def submitted?(%__MODULE__{submitted: submitted}), do: submitted

  def can_check_out?(%__MODULE__{status: :checked_in, submitted: false}), do: true
  def can_check_out?(_), do: false

  def can_submit?(%__MODULE__{status: status, submitted: false})
      when status in [:checked_out, :absent, :excused], do: true

  def can_submit?(_), do: false

  def finalized?(%__MODULE__{status: status}) when status in [:checked_out, :absent, :excused],
    do: true

  def finalized?(_), do: false

  @doc "Returns attendance duration in seconds, or nil if check-in/out incomplete."
  def attendance_duration(%__MODULE__{
        check_in_at: %DateTime{} = check_in,
        check_out_at: %DateTime{} = check_out
      }) do
    DateTime.diff(check_out, check_in, :second)
  end

  def attendance_duration(_), do: nil

  # Private validation functions

  defp validate(record) do
    []
    |> validate_check_times(record.check_in_at, record.check_out_at)
    |> validate_status(record.status)
    |> validate_submission(record.submitted, record.submitted_at, record.submitted_by)
  end

  defp validate_check_times(errors, %DateTime{} = check_in, %DateTime{} = check_out) do
    case DateTime.compare(check_out, check_in) do
      :lt -> ["Check-out time cannot be before check-in time" | errors]
      _ -> errors
    end
  end

  defp validate_check_times(errors, _, _), do: errors

  defp validate_status(errors, status)
       when status in [:expected, :checked_in, :checked_out, :absent, :excused] do
    errors
  end

  defp validate_status(errors, status) do
    [
      "Invalid status: #{inspect(status)}. Must be one of: :expected, :checked_in, :checked_out, :absent, :excused"
      | errors
    ]
  end

  defp validate_submission(errors, true, nil, _) do
    ["Submitted records must have submitted_at" | errors]
  end

  defp validate_submission(errors, true, _, nil) do
    ["Submitted records must have submitted_by" | errors]
  end

  defp validate_submission(errors, _, _, _), do: errors
end
