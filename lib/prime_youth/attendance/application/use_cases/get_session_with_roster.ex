defmodule PrimeYouth.Attendance.Application.UseCases.GetSessionWithRoster do
  @moduledoc """
  Retrieves a program session with its attendance roster.

  ## Architecture
  - Application Layer: Orchestrates queries across repositories
  - Adapter Layer: SessionRepository and AttendanceRepository for data access

  ## Use Case
  Returns a session along with all attendance records for that session,
  enabling display of the attendance roster for check-in/out operations.
  """

  require Logger

  @doc """
  Fetches a session with its attendance records.

  ## Parameters
  - `session_id` - Binary UUID of the session

  ## Returns
  - `{:ok, session_with_roster}` - Map containing :session and :attendance_records
  - `{:error, reason}` - Fetch failed
    - `:not_found` - Session does not exist
    - Database errors
  """
  def execute(session_id) when is_binary(session_id) do
    with {:ok, session} <- session_repository().get_by_id(session_id),
         {:ok, records} <- attendance_repository().list_by_session(session_id) do
      {:ok, Map.put(session, :attendance_records, records)}
    end
  end

  @doc """
  Fetches a session with enriched attendance records (includes child names).

  Similar to `execute/1` but uses `list_by_session_enriched/1` which joins
  with the children table to include child first_name and last_name fields.
  Used by provider attendance view to display child names without separate queries.

  ## Parameters
  - `session_id` - Binary UUID of the session

  ## Returns
  - `{:ok, session_with_roster}` - Map containing :session and enriched :attendance_records
  - `{:error, reason}` - Fetch failed
    - `:not_found` - Session does not exist
    - Database errors
  """
  def execute_enriched(session_id) when is_binary(session_id) do
    with {:ok, session} <- session_repository().get_by_id(session_id),
         {:ok, enriched_records} <- attendance_repository().list_by_session_enriched(session_id) do
      {:ok, Map.put(session, :attendance_records, enriched_records)}
    end
  end

  defp session_repository do
    Application.get_env(:prime_youth, :attendance)[:session_repository]
  end

  defp attendance_repository do
    Application.get_env(:prime_youth, :attendance)[:attendance_repository]
  end
end
