defmodule PrimeYouth.ProgramCatalog.Domain.Models.Program do
  @moduledoc """
  Pure domain entity representing an afterschool program, camp, or class trip.

  This is the aggregate root for the Program Catalog bounded context.
  Contains only business logic and validation rules, no database dependencies.
  """

  @enforce_keys [
    :id,
    :title,
    :description,
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
    :schedule,
    :age_range,
    :price,
    :pricing_period,
    :spots_available,
    :gradient_class,
    :icon_path,
    :inserted_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          description: String.t(),
          schedule: String.t(),
          age_range: String.t(),
          price: Decimal.t(),
          pricing_period: String.t(),
          spots_available: non_neg_integer(),
          gradient_class: String.t() | nil,
          icon_path: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

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
    title_valid?(program.title) and
      description_valid?(program.description) and
      price_valid?(program.price) and
      spots_valid?(program.spots_available)
  end

  defp title_valid?(title) when is_binary(title) do
    trimmed = String.trim(title)
    trimmed != "" and String.length(trimmed) <= 100
  end

  defp title_valid?(_), do: false

  defp description_valid?(description) when is_binary(description) do
    trimmed = String.trim(description)
    trimmed != "" and String.length(trimmed) <= 500
  end

  defp description_valid?(_), do: false

  defp price_valid?(%Decimal{} = price), do: Decimal.compare(price, Decimal.new(0)) != :lt
  defp price_valid?(_), do: false

  defp spots_valid?(spots) when is_integer(spots) and spots >= 0, do: true
  defp spots_valid?(_), do: false

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
