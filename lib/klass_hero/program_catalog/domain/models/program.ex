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
    :provider_id,
    :title,
    :description,
    :category,
    :schedule,
    :age_range,
    :price,
    :pricing_period,
    :spots_available,
    :icon_path,
    :end_date,
    :lock_version,
    :inserted_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          provider_id: String.t() | nil,
          title: String.t(),
          description: String.t(),
          category: String.t(),
          schedule: String.t(),
          age_range: String.t(),
          price: Decimal.t(),
          pricing_period: String.t(),
          spots_available: non_neg_integer(),
          icon_path: String.t() | nil,
          end_date: DateTime.t() | nil,
          lock_version: non_neg_integer() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Creates a new Program from validated attributes.

  Assumes data has passed Ecto schema validation. Use this when creating
  a Program from data that has already been validated by the persistence layer.

  ## Examples

      iex> Program.new(%{
      ...>   id: "1",
      ...>   title: "Art Adventures",
      ...>   description: "Creative art program",
      ...>   category: "arts",
      ...>   schedule: "Mon-Fri 3-5pm",
      ...>   age_range: "6-10 years",
      ...>   price: Decimal.new("50.00"),
      ...>   pricing_period: "week",
      ...>   spots_available: 10
      ...> })
      {:ok, %Program{...}}
  """
  @spec new(map()) :: {:ok, t()}
  def new(attrs) when is_map(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  end

  @doc """
  Creates a new Program, raising on missing required keys.

  Use when data source is trusted (e.g., from mapper after Ecto validation).

  ## Examples

      iex> Program.new!(%{id: "1", title: "Art", ...})
      %Program{...}
  """
  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    struct!(__MODULE__, attrs)
  end

  @doc """
  Checks if the program struct has valid business invariants.

  Note: Full validation is performed by the Ecto schema. This function
  only checks runtime invariants that matter for business logic.
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = program) do
    is_binary(program.title) and String.trim(program.title) != "" and
      is_binary(program.description) and String.trim(program.description) != "" and
      match?(%Decimal{}, program.price) and Decimal.compare(program.price, Decimal.new(0)) != :lt and
      is_integer(program.spots_available) and program.spots_available >= 0
  end

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
