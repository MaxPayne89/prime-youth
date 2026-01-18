defmodule KlassHero.ProgramCatalog.Domain.Services.TrendingSearches do
  @moduledoc """
  Domain service for trending search terms.

  Provides popular search suggestions for the home page hero section.
  """

  @trending_searches ["Swimming", "Math Tutor", "Summer Camp", "Piano", "Soccer"]

  @doc """
  Returns all trending search terms.

  ## Examples

      iex> TrendingSearches.list()
      ["Swimming", "Math Tutor", "Summer Camp", "Piano", "Soccer"]
  """
  @spec list() :: [String.t()]
  def list, do: @trending_searches

  @doc """
  Returns up to `max` trending search terms.

  ## Examples

      iex> TrendingSearches.list(3)
      ["Swimming", "Math Tutor", "Summer Camp"]

      iex> TrendingSearches.list(10)
      ["Swimming", "Math Tutor", "Summer Camp", "Piano", "Soccer"]
  """
  @spec list(pos_integer()) :: [String.t()]
  def list(max) when is_integer(max) and max > 0, do: Enum.take(@trending_searches, max)
end
