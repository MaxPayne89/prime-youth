defmodule PrimeYouth.Attendance.Application.UseCases.GetAttendanceHistory do
  @moduledoc """
  Queries attendance records with flexible filtering for different views.

  ## Architecture
  - Application Layer: Routes queries to appropriate repository methods
  - Adapter Layer: AttendanceRepository handles database queries with ordering

  ## Query Options
  - `:by_child` - All records for a specific child (ordered by session_date desc)
  - `:by_session` - All records for a specific session
  - `:by_parent` - All records for parent's children (ordered by session_date desc)

  ## Events
  No events published for read operations.
  """

  @doc """
  Queries attendance history based on filter type.

  ## Parameters
  - `filter_type` - Atom indicating filter type (`:by_child`, `:by_session`, or `:by_parent`)
  - `filter_value` - Value to filter by (child_id, session_id, or parent_id)

  ## Returns
  - `[AttendanceRecord.t()]` - List of matching attendance records (may be empty)
  - `{:error, {:invalid_filter_type, atom()}}` - Invalid filter type provided

  ## Examples

      iex> GetAttendanceHistory.execute(:by_child, child_id)
      [%AttendanceRecord{}, ...]

      iex> GetAttendanceHistory.execute(:by_session, session_id)
      [%AttendanceRecord{}, ...]

      iex> GetAttendanceHistory.execute(:by_parent, parent_id)
      [%AttendanceRecord{}, ...]

      iex> GetAttendanceHistory.execute(:invalid_filter, "value")
      {:error, {:invalid_filter_type, :invalid_filter}}
  """
  def execute(:by_child, child_id) when is_binary(child_id) do
    attendance_repository().list_by_child(child_id)
  end

  def execute(:by_session, session_id) when is_binary(session_id) do
    attendance_repository().list_by_session(session_id)
  end

  def execute(:by_parent, parent_id) when is_binary(parent_id) do
    attendance_repository().list_by_parent(parent_id)
  end

  def execute(filter_type, _filter_value) do
    {:error, {:invalid_filter_type, filter_type}}
  end

  # Dependency injection: fetch repository from application config
  defp attendance_repository do
    Application.get_env(:prime_youth, :attendance)[:attendance_repository]
  end
end
