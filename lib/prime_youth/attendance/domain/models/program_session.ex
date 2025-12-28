defmodule PrimeYouth.Attendance.Domain.Models.ProgramSession do
  @moduledoc """
  Pure domain entity for program session instances.

  ## Status Lifecycle

  - `:scheduled → :in_progress → :completed` (normal flow)
  - `:scheduled → :cancelled` or `:in_progress → :cancelled` (cancellation)

  Capacity: max_capacity = 0 means unlimited.
  """

  @enforce_keys [
    :id,
    :program_id,
    :session_date,
    :start_time,
    :end_time,
    :max_capacity,
    :status
  ]

  defstruct [
    :id,
    :program_id,
    :session_date,
    :start_time,
    :end_time,
    :max_capacity,
    :status,
    :notes,
    :lock_version,
    :inserted_at,
    :updated_at
  ]

  @doc """
  Creates a new ProgramSession with validation.

  Business Rules: max_capacity ≥ 0 (0 = unlimited); end_time > start_time.
  """
  def new(attrs) do
    session = struct!(__MODULE__, attrs)

    case validate(session) do
      [] -> {:ok, session}
      errors -> {:error, errors}
    end
  end

  @doc "Validates business rules."
  def valid?(session) do
    validate(session) == []
  end

  @doc "Transitions :scheduled → :in_progress."
  def start_session(%__MODULE__{status: :scheduled} = session) do
    {:ok, %{session | status: :in_progress}}
  end

  def start_session(%__MODULE__{status: status}) do
    {:error, "Cannot start session with status: #{status}"}
  end

  @doc "Transitions :in_progress → :completed."
  def complete_session(%__MODULE__{status: :in_progress} = session) do
    {:ok, %{session | status: :completed}}
  end

  def complete_session(%__MODULE__{status: status}) do
    {:error, "Cannot complete session with status: #{status}"}
  end

  @doc "Transitions :scheduled or :in_progress → :cancelled."
  def cancel_session(%__MODULE__{status: status} = session)
      when status in [:scheduled, :in_progress] do
    {:ok, %{session | status: :cancelled}}
  end

  def cancel_session(%__MODULE__{status: status}) do
    {:error, "Cannot cancel session with status: #{status}"}
  end

  def can_start?(%__MODULE__{status: :scheduled}), do: true
  def can_start?(_), do: false

  def can_complete?(%__MODULE__{status: :in_progress}), do: true
  def can_complete?(_), do: false

  @doc "Returns true if session has capacity. max_capacity = 0 means unlimited."
  def has_capacity?(%__MODULE__{max_capacity: 0}, _current_count), do: true
  def has_capacity?(%__MODULE__{max_capacity: max}, current) when current < max, do: true
  def has_capacity?(_session, _current_count), do: false

  def active?(%__MODULE__{status: :in_progress}), do: true
  def active?(_), do: false

  def finalized?(%__MODULE__{status: status}) when status in [:completed, :cancelled], do: true
  def finalized?(_), do: false

  # Private validation functions

  defp validate(session) do
    []
    |> validate_max_capacity(session.max_capacity)
    |> validate_time_range(session.start_time, session.end_time)
    |> validate_status(session.status)
    |> validate_session_date(session.session_date)
  end

  defp validate_max_capacity(errors, capacity) when is_integer(capacity) and capacity >= 0 do
    errors
  end

  defp validate_max_capacity(errors, capacity) when is_integer(capacity) do
    ["Max capacity cannot be negative" | errors]
  end

  defp validate_max_capacity(errors, _) do
    ["Max capacity must be an integer" | errors]
  end

  defp validate_time_range(errors, %Time{} = start_time, %Time{} = end_time) do
    case Time.compare(end_time, start_time) do
      :gt -> errors
      _ -> ["End time must be after start time" | errors]
    end
  end

  defp validate_time_range(errors, _, _) do
    ["Start time and end time must be valid Time structs" | errors]
  end

  defp validate_status(errors, status)
       when status in [:scheduled, :in_progress, :completed, :cancelled] do
    errors
  end

  defp validate_status(errors, status) do
    [
      "Invalid status: #{inspect(status)}. Must be one of: :scheduled, :in_progress, :completed, :cancelled"
      | errors
    ]
  end

  defp validate_session_date(errors, %Date{}), do: errors

  defp validate_session_date(errors, _) do
    ["Session date must be a valid Date struct" | errors]
  end
end
