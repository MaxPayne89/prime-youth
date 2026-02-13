defmodule KlassHero.ProgramCatalog.Domain.Services.ProgramCategories do
  @moduledoc """
  Domain service for program category operations.

  Centralizes knowledge about valid program categories and filter validation
  for the Program Catalog context.
  """

  alias KlassHero.Shared.Categories

  @valid_categories ["all" | Categories.categories()]

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

  @doc """
  Returns valid categories for programs (excludes "all" which is only for filtering).

  ## Examples

      iex> ProgramCategories.program_categories()
      ["sports", "arts", "music", "education", "life-skills", "camps", "workshops"]
  """
  @spec program_categories() :: [String.t()]
  def program_categories, do: Categories.categories()

  @doc """
  Checks if a category is valid for assignment to a program.

  Unlike `valid?/1`, this excludes "all" which is only valid as a filter.

  ## Examples

      iex> ProgramCategories.valid_program_category?("sports")
      true

      iex> ProgramCategories.valid_program_category?("all")
      false

      iex> ProgramCategories.valid_program_category?("invalid")
      false
  """
  @spec valid_program_category?(String.t()) :: boolean()
  def valid_program_category?(category), do: category in program_categories()
end
