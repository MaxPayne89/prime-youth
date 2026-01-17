defmodule KlassHero.ProgramCatalog.Domain.Services.ProgramPricing do
  @moduledoc """
  Domain service for program pricing operations.

  Centralizes all price formatting and calculation logic for the Program Catalog context.
  """

  @default_currency "€"
  @default_program_weeks 4

  @doc """
  Formats a price for display with currency symbol.

  Handles Decimal, integer, and float inputs.

  ## Examples

      iex> ProgramPricing.format_price(Decimal.new("45.00"))
      "€45.00"

      iex> ProgramPricing.format_price(45)
      "€45.00"

      iex> ProgramPricing.format_price(45.50)
      "€45.50"
  """
  @spec format_price(Decimal.t() | number()) :: String.t()
  def format_price(%Decimal{} = price) do
    "#{@default_currency}#{Decimal.to_string(price)}"
  end

  def format_price(price) when is_integer(price) do
    "#{@default_currency}#{price}.00"
  end

  def format_price(price) when is_float(price) do
    "#{@default_currency}#{:erlang.float_to_binary(price, decimals: 2)}"
  end

  @doc """
  Calculates total price for a standard program duration.

  Programs are charged weekly, with a default duration of #{@default_program_weeks} weeks.

  ## Examples

      iex> ProgramPricing.calculate_total(Decimal.new("45.00"))
      Decimal.new("180.00")
  """
  @spec calculate_total(Decimal.t()) :: Decimal.t()
  def calculate_total(%Decimal{} = weekly_price) do
    Decimal.mult(weekly_price, @default_program_weeks)
  end

  @doc """
  Formats the total price for display.

  Combines `calculate_total/1` and `format_price/1` for convenience.

  ## Examples

      iex> ProgramPricing.format_total_price(Decimal.new("45.00"))
      "€180.00"
  """
  @spec format_total_price(Decimal.t()) :: String.t()
  def format_total_price(%Decimal{} = weekly_price) do
    weekly_price
    |> calculate_total()
    |> format_price()
  end

  @doc """
  Returns the default program duration in weeks.
  """
  @spec default_program_weeks() :: pos_integer()
  def default_program_weeks, do: @default_program_weeks

  @doc """
  Returns the default currency symbol.
  """
  @spec default_currency() :: String.t()
  def default_currency, do: @default_currency
end
