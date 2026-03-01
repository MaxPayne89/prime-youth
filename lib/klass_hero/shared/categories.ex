defmodule KlassHero.Shared.Categories do
  @moduledoc """
  Shared vocabulary for program/activity categories.

  Lives in the Shared kernel so that both Identity (staff member tag validation)
  and ProgramCatalog (program category filtering) can reference the canonical
  category list without creating a cyclic dependency.
  """

  @categories [
    "sports",
    "arts",
    "music",
    "education",
    "life-skills",
    "camps",
    "workshops"
  ]

  @doc """
  Returns the canonical list of activity categories.

  ## Examples

      iex> KlassHero.Shared.Categories.categories()
      ["sports", "arts", "music", "education", "life-skills", "camps", "workshops"]
  """
  @spec categories() :: [String.t()]
  def categories, do: @categories

  @doc """
  Checks if a category string is valid.

  ## Examples

      iex> KlassHero.Shared.Categories.valid_category?("sports")
      true

      iex> KlassHero.Shared.Categories.valid_category?("invalid")
      false
  """
  @spec valid_category?(String.t()) :: boolean()
  def valid_category?(category), do: category in @categories
end
