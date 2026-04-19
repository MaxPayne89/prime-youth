defmodule KlassHero.Provider.Domain.Ports.ForQueryingSessionStats do
  @moduledoc """
  Read-only port for querying provider session statistics.

  Separated from the write side of the projection. Read operations never mutate state.
  """

  alias KlassHero.Provider.Domain.ReadModels.SessionStats

  @doc """
  Lists all session stats for a provider, ordered by sessions_completed_count descending.

  Returns an empty list when no stats exist for the given provider.
  """
  @callback list_for_provider(provider_id :: binary()) :: [SessionStats.t()]

  @doc """
  Returns the total completed session count across all programs for a provider.

  Returns 0 when no stats exist for the given provider.
  """
  @callback get_total_count(provider_id :: binary()) :: non_neg_integer()
end
