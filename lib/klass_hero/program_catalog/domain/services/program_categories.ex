defmodule KlassHero.ProgramCatalog.Domain.Services.ProgramCategories do
  @moduledoc """
  Domain service for program category operations.

  Centralizes knowledge about valid program categories and filter validation
  for the Program Catalog context.
  """

  @valid_categories [
    "all",
    "sports",
    "arts",
    "music",
    "education",
    "life-skills",
    "camps",
    "workshops"
  ]

  @default_category "all"

  @doc """
  Returns all valid category identifiers.

  ## Examples

      iex> ProgramCategories.valid_categories()
      ["all", "sports", "arts", "music", "education", "life-skills", "camps", "workshops"]
  """
  @spec valid_categories() :: [String.t()]
  def valid_categories, do: @valid_categories

  @doc """
  Validates a category filter, returning default for invalid values.

  Returns "all" for nil or invalid category strings.

  ## Examples

      iex> ProgramCategories.validate_filter("sports")
      "sports"

      iex> ProgramCategories.validate_filter(nil)
      "all"

      iex> ProgramCategories.validate_filter("invalid")
      "all"
  """
  @spec validate_filter(String.t() | nil) :: String.t()
  def validate_filter(nil), do: @default_category
  def validate_filter(filter) when filter in @valid_categories, do: filter
  def validate_filter(_invalid), do: @default_category

  @doc """
  Checks if a category is valid.

  ## Examples

      iex> ProgramCategories.valid?("sports")
      true

      iex> ProgramCategories.valid?("invalid")
      false
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(category), do: category in @valid_categories

  @doc """
  Returns the default category.
  """
  @spec default_category() :: String.t()
  def default_category, do: @default_category
end
