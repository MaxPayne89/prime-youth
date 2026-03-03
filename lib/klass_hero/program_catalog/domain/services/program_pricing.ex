defmodule KlassHero.ProgramCatalog.Domain.Services.ProgramPricing do
  @moduledoc """
  Domain service for program pricing operations.

  Centralizes all price formatting logic for the Program Catalog context.
  """

  @default_currency "€"

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
  @spec format_price(Decimal.t() | number() | nil) :: String.t()
  def format_price(nil), do: "N/A"

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
  Returns the default currency symbol.
  """
  @spec default_currency() :: String.t()
  def default_currency, do: @default_currency
end
