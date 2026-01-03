defmodule KlassHero.Participation.Application.UseCases.ListSessions do
  @moduledoc """
  Use case for listing sessions.

  Supports filtering by program or by date.
  """

  alias KlassHero.Participation.Domain.Models.ProgramSession

  @type params :: %{
          optional(:program_id) => String.t(),
          optional(:date) => Date.t()
        }

  @type result :: [ProgramSession.t()]

  @doc """
  Lists sessions based on filter criteria.

  ## Parameters

  - `params` - Map containing filter options:
    - `program_id` - Filter by program ID
    - `date` - Filter by specific date

  ## Returns

  List of sessions matching the criteria.
  """
  @spec execute(params()) :: result()
  def execute(%{program_id: program_id}) when is_binary(program_id) do
    session_repository().list_by_program(program_id)
  end

  def execute(%{date: %Date{} = date}) do
    session_repository().list_today_sessions(date)
  end

  def execute(%{}) do
    # Default to today's sessions if no filter specified
    session_repository().list_today_sessions(Date.utc_today())
  end

  defp session_repository do
    Application.get_env(:klass_hero, :participation)[:session_repository]
  end
end
