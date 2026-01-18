defmodule KlassHero.ProgramCatalog.Domain.Models.Program do
  @moduledoc """
  Pure domain entity representing an afterschool program, camp, or class trip.

  This is the aggregate root for the Program Catalog bounded context.
  Contains only business logic and validation rules, no database dependencies.
  """

  @enforce_keys [
    :id,
    :title,
    :description,
    :category,
    :schedule,
    :age_range,
    :price,
    :pricing_period,
    :spots_available
  ]

  defstruct [
    :id,
    :title,
    :description,
    :category,
    :schedule,
    :age_range,
    :price,
    :pricing_period,
    :spots_available,
    :icon_path,
    :lock_version,
    :inserted_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          description: String.t(),
          category: String.t(),
          schedule: String.t(),
          age_range: String.t(),
          price: Decimal.t(),
          pricing_period: String.t(),
          spots_available: non_neg_integer(),
          icon_path: String.t() | nil,
          lock_version: non_neg_integer() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Creates a new Program with validation.

  Business Rules:
  - Title must be present, non-empty, and <= 100 characters
  - Description must be present, non-empty, and <= 500 characters
  - Price must be >= 0 (free programs allowed)
  - Spots available must be >= 0 (sold out = 0)
  - Schedule must be present and non-empty
  - Age range must be present and non-empty
  - Pricing period must be present and non-empty

  Returns:
  - `{:ok, program}` if all validations pass
  - `{:error, [reasons]}` with list of validation errors

  ## Examples

      iex> Program.new(%{
      ...>   id: "1",
      ...>   title: "Art Adventures",
      ...>   description: "Creative art program",
      ...>   schedule: "Mon-Fri 3-5pm",
      ...>   age_range: "6-10 years",
      ...>   price: Decimal.new("50.00"),
      ...>   pricing_period: "week",
      ...>   spots_available: 10
      ...> })
      {:ok, %Program{...}}

      iex> Program.new(%{id: "1", title: "", ...})
      {:error, ["Title cannot be empty", ...]}
  """
  @spec new(map()) :: {:ok, t()} | {:error, [String.t()]}
  def new(attrs) do
    program = struct!(__MODULE__, attrs)

    case validate(program) do
      [] -> {:ok, program}
      errors -> {:error, errors}
    end
  end

  @doc """
  Validates that a program struct has valid business rules.

  Business Rules:
  - Title must be present and non-empty
  - Description must be present and non-empty
  - Price must be >= 0 (free programs allowed)
  - Spots available must be >= 0 (sold out = 0)
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = program) do
    validate(program) == []
  end

  defp validate(%__MODULE__{} = program) do
    []
    |> validate_title(program.title)
    |> validate_description(program.description)
    |> validate_category(program.category)
    |> validate_schedule(program.schedule)
    |> validate_age_range(program.age_range)
    |> validate_pricing_period(program.pricing_period)
    |> validate_price(program.price)
    |> validate_spots(program.spots_available)
  end

  defp validate_title(errors, title) when is_binary(title) do
    trimmed = String.trim(title)

    cond do
      trimmed == "" -> ["Title cannot be empty" | errors]
      String.length(trimmed) > 100 -> ["Title must be 100 characters or less" | errors]
      true -> errors
    end
  end

  defp validate_title(errors, _), do: ["Title must be a string" | errors]

  defp validate_description(errors, description) when is_binary(description) do
    trimmed = String.trim(description)

    cond do
      trimmed == "" -> ["Description cannot be empty" | errors]
      String.length(trimmed) > 500 -> ["Description must be 500 characters or less" | errors]
      true -> errors
    end
  end

  defp validate_description(errors, _), do: ["Description must be a string" | errors]

  defp validate_category(errors, category) when is_binary(category) do
    alias KlassHero.ProgramCatalog.Domain.Services.ProgramCategories

    if ProgramCategories.valid_program_category?(category) do
      errors
    else
      [
        "Category must be one of: #{Enum.join(ProgramCategories.program_categories(), ", ")}"
        | errors
      ]
    end
  end

  defp validate_category(errors, _), do: ["Category must be a string" | errors]

  defp validate_schedule(errors, schedule) when is_binary(schedule) do
    if String.trim(schedule) == "" do
      ["Schedule cannot be empty" | errors]
    else
      errors
    end
  end

  defp validate_schedule(errors, _), do: ["Schedule must be a string" | errors]

  defp validate_age_range(errors, age_range) when is_binary(age_range) do
    if String.trim(age_range) == "" do
      ["Age range cannot be empty" | errors]
    else
      errors
    end
  end

  defp validate_age_range(errors, _), do: ["Age range must be a string" | errors]

  defp validate_pricing_period(errors, pricing_period) when is_binary(pricing_period) do
    if String.trim(pricing_period) == "" do
      ["Pricing period cannot be empty" | errors]
    else
      errors
    end
  end

  defp validate_pricing_period(errors, _), do: ["Pricing period must be a string" | errors]

  defp validate_price(errors, %Decimal{} = price) do
    if Decimal.compare(price, Decimal.new(0)) == :lt do
      ["Price cannot be negative" | errors]
    else
      errors
    end
  end

  defp validate_price(errors, _), do: ["Price must be a Decimal" | errors]

  defp validate_spots(errors, spots) when is_integer(spots) do
    if spots < 0 do
      ["Spots available cannot be negative" | errors]
    else
      errors
    end
  end

  defp validate_spots(errors, _), do: ["Spots available must be an integer" | errors]

  @doc """
  Checks if the program is sold out (no spots available).
  """
  @spec sold_out?(t()) :: boolean()
  def sold_out?(%__MODULE__{spots_available: spots}), do: spots == 0

  @doc """
  Checks if the program is free (price is $0).
  """
  @spec free?(t()) :: boolean()
  def free?(%__MODULE__{price: price}), do: Decimal.equal?(price, Decimal.new(0))
end
