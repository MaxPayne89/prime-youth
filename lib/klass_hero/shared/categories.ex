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

  @doc """
  Returns the heroicon name for a given category.

  Used by UI components to render category-appropriate icons.

  ## Examples

      iex> KlassHero.Shared.Categories.icon_name("sports")
      "hero-trophy"

      iex> KlassHero.Shared.Categories.icon_name(nil)
      "hero-academic-cap"
  """
  @spec icon_name(String.t() | nil) :: String.t()
  def icon_name("sports"), do: "hero-trophy"
  def icon_name("arts"), do: "hero-paint-brush"
  def icon_name("music"), do: "hero-musical-note"
  def icon_name("education"), do: "hero-academic-cap"
  def icon_name("life-skills"), do: "hero-light-bulb"
  def icon_name("camps"), do: "hero-fire"
  def icon_name("workshops"), do: "hero-wrench-screwdriver"
  def icon_name(_), do: "hero-academic-cap"
end
