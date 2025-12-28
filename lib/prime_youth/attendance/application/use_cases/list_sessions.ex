defmodule PrimeYouth.Attendance.Application.UseCases.ListSessions do
  @moduledoc """
  Lists program sessions with flexible filtering options.

  ## Architecture
  - Application Layer: Routes queries to appropriate repository methods
  - Adapter Layer: SessionRepository handles database queries with ordering

  ## Query Options
  - `:by_program` - Lists all sessions for a specific program (ordered by date, then time)
  - `:today` - Lists all sessions for a specific date (ordered by time)

  ## Events
  No events published for read operations.
  """

  @doc """
  Lists sessions based on filter type.

  ## Parameters
  - `filter_type` - Atom indicating filter type (`:by_program` or `:today`)
  - `filter_value` - Value to filter by (program_id or date)

  ## Returns
  - `[ProgramSession.t()]` - List of matching sessions (may be empty)
  - `{:error, {:invalid_filter_type, atom()}}` - Invalid filter type provided

  ## Examples

      iex> ListSessions.execute(:by_program, program_id)
      [%ProgramSession{}, ...]

      iex> ListSessions.execute(:today, ~D[2025-01-15])
      [%ProgramSession{}, ...]

      iex> ListSessions.execute(:invalid_filter, "value")
      {:error, {:invalid_filter_type, :invalid_filter}}
  """
  def execute(:by_program, program_id) when is_binary(program_id) do
    session_repository().list_by_program(program_id)
  end

  def execute(:today, %Date{} = date) do
    session_repository().list_today_sessions(date)
  end

  def execute(filter_type, _filter_value) do
    {:error, {:invalid_filter_type, filter_type}}
  end

  # Dependency injection: fetch repository from application config
  defp session_repository do
    Application.get_env(:prime_youth, :attendance)[:session_repository]
  end
end
