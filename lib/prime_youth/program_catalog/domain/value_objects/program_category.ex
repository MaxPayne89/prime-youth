defmodule PrimeYouth.ProgramCatalog.Domain.ValueObjects.ProgramCategory do
  @moduledoc """
  ProgramCategory value object.

  Represents a valid program category with display name formatting.
  Immutable value object following DDD principles.
  """

  @type t :: %__MODULE__{
          value: String.t()
        }

  defstruct [:value]

  @valid_categories [
    "sports",
    "arts",
    "stem",
    "academic",
    "music",
    "dance",
    "language",
    "outdoor",
    "leadership",
    "other"
  ]

  @display_names %{
    "sports" => "Sports & Athletics",
    "arts" => "Arts & Crafts",
    "stem" => "STEM & Technology",
    "academic" => "Academic Enrichment",
    "music" => "Music & Performance",
    "dance" => "Dance & Movement",
    "language" => "Language & Culture",
    "outdoor" => "Outdoor Adventures",
    "leadership" => "Leadership & Life Skills",
    "other" => "Other Activities"
  }

  @doc """
  Creates a new ProgramCategory value object.

  ## Parameters
    - value: The category name (string)

  ## Returns
    - `{:ok, %ProgramCategory{}}` if valid
    - `{:error, reason}` if invalid

  ## Examples

      iex> ProgramCategory.new("sports")
      {:ok, %ProgramCategory{value: "sports"}}

      iex> ProgramCategory.new("SPORTS")
      {:ok, %ProgramCategory{value: "sports"}}

      iex> ProgramCategory.new("  sports  ")
      {:ok, %ProgramCategory{value: "sports"}}

      iex> ProgramCategory.new("invalid")
      {:error, "Invalid category: invalid"}

      iex> ProgramCategory.new(nil)
      {:error, "Category cannot be nil"}

      iex> ProgramCategory.new("")
      {:error, "Category cannot be empty"}
  """
  @spec new(String.t() | nil) :: {:ok, t()} | {:error, String.t()}
  def new(nil), do: {:error, "Category cannot be nil"}

  def new(value) when is_binary(value) do
    normalized = value |> String.trim() |> String.downcase()

    cond do
      normalized == "" ->
        {:error, "Category cannot be empty"}

      normalized not in @valid_categories ->
        {:error, "Invalid category: #{value}"}

      true ->
        {:ok, %__MODULE__{value: normalized}}
    end
  end

  @doc """
  Returns the formatted display name for a category.

  ## Parameters
    - category: The ProgramCategory struct

  ## Returns
    - String: The formatted display name

  ## Examples

      iex> {:ok, category} = ProgramCategory.new("sports")
      iex> ProgramCategory.display_name(category)
      "Sports & Athletics"

      iex> {:ok, category} = ProgramCategory.new("stem")
      iex> ProgramCategory.display_name(category)
      "STEM & Technology"
  """
  @spec display_name(t()) :: String.t()
  def display_name(%__MODULE__{value: value}) do
    Map.get(@display_names, value, String.capitalize(value))
  end

  @doc """
  Returns a list of all valid category values.

  ## Returns
    - List of valid category strings

  ## Examples

      iex> ProgramCategory.all()
      ["sports", "arts", "stem", "academic", "music", "dance", "language", "outdoor", "leadership", "other"]
  """
  @spec all() :: [String.t()]
  def all do
    @valid_categories
  end
end
