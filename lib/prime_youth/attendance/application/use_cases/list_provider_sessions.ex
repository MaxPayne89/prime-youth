defmodule PrimeYouth.Attendance.Application.UseCases.ListProviderSessions do
  @moduledoc """
  Lists program sessions for a provider on a specific date.

  ## Architecture
  - Application Layer: Routes queries to session repository
  - Adapter Layer: SessionRepository handles database queries with ordering

  ## Use Case
  Returns all sessions for a provider on a given date, ordered by start time.
  Used by provider dashboard to display daily session schedule.

  ## Note
  Full provider filtering requires schema updates to establish
  provider-program relationship. Currently filters by date only.
  """

  require Logger

  @doc """
  Lists sessions for a provider on a specific date.

  ## Parameters
  - `provider_id` - Binary UUID of the provider
  - `date` - Date to filter sessions

  ## Returns
  - `{:ok, [session]}` - List of matching sessions
  - `{:error, reason}` - Query failed
    - Database errors

  ## Examples

      iex> ListProviderSessions.execute(provider_id, ~D[2025-01-15])
      {:ok, [%ProgramSession{}, ...]}
  """
  def execute(provider_id, %Date{} = date) when is_binary(provider_id) do
    session_repository().list_by_provider_and_date(provider_id, date)
  end

  defp session_repository do
    Application.get_env(:prime_youth, :attendance)[:session_repository]
  end
end
