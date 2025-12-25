defmodule PrimeYouth.Attendance.Application.UseCases.GetAttendanceRecord do
  @moduledoc """
  Retrieves a single attendance record by its ID.

  ## Architecture
  - Application Layer: Simple query wrapper for single record retrieval
  - Adapter Layer: AttendanceRepository handles data access

  ## Use Case
  Returns an attendance record for display or further operations,
  such as viewing attendance details in parent history views.
  """

  require Logger

  @doc """
  Fetches an attendance record by ID.

  ## Parameters
  - `record_id` - Binary UUID of the attendance record

  ## Returns
  - `{:ok, record}` - The attendance record
  - `{:error, reason}` - Fetch failed
    - `:not_found` - Record does not exist
    - Database errors
  """
  def execute(record_id) when is_binary(record_id) do
    attendance_repository().get_by_id(record_id)
  end

  defp attendance_repository do
    Application.get_env(:prime_youth, :attendance)[:attendance_repository]
  end
end
