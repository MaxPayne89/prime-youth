defmodule PrimeYouth.ProgramCatalog.Domain.ValueObjects.AgeRange do
  @moduledoc """
  AgeRange value object for youth programs.

  Represents a valid age range with validation constraints:
  - Ages must be between 0 and 18 (youth programs)
  - Min age cannot exceed max age
  - Both values must be integers

  Immutable value object following DDD principles.
  """

  @type t :: %__MODULE__{
          min_age: non_neg_integer(),
          max_age: non_neg_integer()
        }

  defstruct [:min_age, :max_age]

  @min_allowed_age 0
  @max_allowed_age 18

  @doc """
  Creates a new AgeRange value object.

  ## Parameters
    - min_age: The minimum age (integer, 0-18)
    - max_age: The maximum age (integer, 0-18)

  ## Returns
    - `{:ok, %AgeRange{}}` if valid
    - `{:error, reason}` if invalid

  ## Examples

      iex> AgeRange.new(5, 12)
      {:ok, %AgeRange{min_age: 5, max_age: 12}}

      iex> AgeRange.new(10, 10)
      {:ok, %AgeRange{min_age: 10, max_age: 10}}

      iex> AgeRange.new(-1, 10)
      {:error, "Min age must be between 0 and 18"}

      iex> AgeRange.new(12, 10)
      {:error, "Min age cannot be greater than max age"}

      iex> AgeRange.new(nil, 10)
      {:error, "Min age must be an integer"}

      iex> AgeRange.new(5, "10")
      {:error, "Max age must be an integer"}
  """
  @spec new(any(), any()) :: {:ok, t()} | {:error, String.t()}
  def new(min_age, max_age) do
    with :ok <- validate_integer(min_age, "Min age"),
         :ok <- validate_integer(max_age, "Max age"),
         :ok <- validate_range(min_age, "Min age"),
         :ok <- validate_range(max_age, "Max age"),
         :ok <- validate_min_max(min_age, max_age) do
      {:ok, %__MODULE__{min_age: min_age, max_age: max_age}}
    end
  end

  @doc """
  Returns a formatted display string for the age range.

  ## Parameters
    - age_range: The AgeRange struct

  ## Returns
    - String: Formatted age range display

  ## Examples

      iex> {:ok, age_range} = AgeRange.new(5, 5)
      iex> AgeRange.display_format(age_range)
      "Age 5"

      iex> {:ok, age_range} = AgeRange.new(5, 12)
      iex> AgeRange.display_format(age_range)
      "Ages 5-12"
  """
  @spec display_format(t()) :: String.t()
  def display_format(%__MODULE__{min_age: age, max_age: age}), do: "Age #{age}"
  def display_format(%__MODULE__{min_age: min, max_age: max}), do: "Ages #{min}-#{max}"

  @doc """
  Checks if two age ranges overlap.

  Ranges overlap if they share any age values, including boundaries.

  ## Parameters
    - range1: First AgeRange struct
    - range2: Second AgeRange struct

  ## Returns
    - boolean: true if ranges overlap, false otherwise

  ## Examples

      iex> {:ok, range1} = AgeRange.new(5, 10)
      iex> {:ok, range2} = AgeRange.new(8, 12)
      iex> AgeRange.overlaps?(range1, range2)
      true

      iex> {:ok, range1} = AgeRange.new(5, 8)
      iex> {:ok, range2} = AgeRange.new(10, 15)
      iex> AgeRange.overlaps?(range1, range2)
      false
  """
  @spec overlaps?(t(), t()) :: boolean()
  def overlaps?(%__MODULE__{} = range1, %__MODULE__{} = range2) do
    range1.min_age <= range2.max_age and range1.max_age >= range2.min_age
  end

  @doc """
  Checks if the age range contains a specific age.

  ## Parameters
    - age_range: The AgeRange struct
    - age: The age to check (integer)

  ## Returns
    - boolean: true if age is within range (inclusive), false otherwise

  ## Examples

      iex> {:ok, age_range} = AgeRange.new(5, 12)
      iex> AgeRange.contains?(age_range, 8)
      true

      iex> {:ok, age_range} = AgeRange.new(5, 12)
      iex> AgeRange.contains?(age_range, 5)
      true

      iex> {:ok, age_range} = AgeRange.new(5, 12)
      iex> AgeRange.contains?(age_range, 13)
      false
  """
  @spec contains?(t(), integer()) :: boolean()
  def contains?(%__MODULE__{min_age: min, max_age: max}, age) when is_integer(age) do
    age >= min and age <= max
  end

  # Private validation functions

  defp validate_integer(value, _field_name) when is_integer(value), do: :ok
  defp validate_integer(_value, field_name), do: {:error, "#{field_name} must be an integer"}

  defp validate_range(age, _field_name) when age >= @min_allowed_age and age <= @max_allowed_age do
    :ok
  end

  defp validate_range(_age, field_name) do
    {:error, "#{field_name} must be between #{@min_allowed_age} and #{@max_allowed_age}"}
  end

  defp validate_min_max(min_age, max_age) when min_age <= max_age, do: :ok
  defp validate_min_max(_min_age, _max_age), do: {:error, "Min age cannot be greater than max age"}
end
