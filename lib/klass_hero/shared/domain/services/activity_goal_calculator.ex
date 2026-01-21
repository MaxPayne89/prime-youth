defmodule KlassHero.Shared.Domain.Services.ActivityGoalCalculator do
  @moduledoc """
  Domain service for calculating family activity goals.

  Temporarily located in Shared context until Progress Tracking bounded context
  is implemented. Once Progress Tracking exists, this service should be moved there.
  """

  @default_weekly_target 5

  @doc """
  Calculates the weekly activity goal progress for a family.
  """
  def calculate(children, opts \\ []) when is_list(children) do
    target = Keyword.get(opts, :target, @default_weekly_target)
    current = sum_sessions(children)
    percentage = calculate_percentage(current, target)

    %{
      current: current,
      target: target,
      percentage: percentage,
      status: goal_status(percentage)
    }
  end

  defp sum_sessions(children) do
    Enum.reduce(children, 0, fn child, acc ->
      acc + extract_session_count(child)
    end)
  end

  defp extract_session_count(%{sessions: sessions}) when is_list(sessions), do: length(sessions)

  defp extract_session_count(%{sessions: sessions}) when is_binary(sessions),
    do: parse_session_string(sessions)

  defp extract_session_count(_), do: 0

  defp parse_session_string(sessions_string) do
    case String.split(sessions_string, "/") do
      [current, _total] ->
        case Integer.parse(current) do
          {count, _} -> count
          :error -> 0
        end

      _ ->
        0
    end
  end

  defp calculate_percentage(current, target) when target > 0,
    do: min(100, div(current * 100, target))

  defp calculate_percentage(_, _), do: 0

  defp goal_status(percentage) when percentage >= 100, do: :achieved
  defp goal_status(percentage) when percentage >= 80, do: :almost_there
  defp goal_status(_), do: :in_progress
end
