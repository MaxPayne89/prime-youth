defmodule PrimeYouth.ProgramCatalog.Domain.ValueObjects.Pricing do
  @moduledoc """
  Pricing value object for program pricing.

  Represents pricing information with:
  - Amount (must be positive, non-zero)
  - Currency (USD, EUR, GBP, CAD)
  - Price unit (per_session, per_month, per_program)
  - Optional discount amount

  Uses Decimal for precise money calculations.
  Immutable value object following DDD principles.
  """

  @type t :: %__MODULE__{
          amount: Decimal.t(),
          currency: String.t(),
          unit: String.t(),
          discount_amount: Decimal.t() | nil
        }

  defstruct [:amount, :currency, :unit, :discount_amount]

  @valid_currencies ["USD", "EUR", "GBP", "CAD"]
  @valid_units ["per_session", "per_month", "per_program"]

  @currency_symbols %{
    "USD" => "$",
    "EUR" => "€",
    "GBP" => "£",
    "CAD" => "CA$"
  }

  @unit_display %{
    "per_session" => "per session",
    "per_month" => "per month",
    "per_program" => "per program"
  }

  @doc """
  Creates a new Pricing value object.

  ## Parameters
    - amount: The price amount (number, must be positive and non-zero)
    - currency: Currency code (string, USD/EUR/GBP/CAD)
    - unit: Price unit (string, per_session/per_month/per_program)
    - discount_amount: Optional discount amount (number or nil, must be less than price)

  ## Returns
    - `{:ok, %Pricing{}}` if valid
    - `{:error, reason}` if invalid

  ## Examples

      iex> Pricing.new(100.00, "USD", "per_session", nil)
      {:ok, %Pricing{amount: Decimal.new("100.00"), currency: "USD", ...}}

      iex> Pricing.new(100, "USD", "per_session", 20)
      {:ok, %Pricing{amount: Decimal.new("100"), discount_amount: Decimal.new("20"), ...}}

      iex> Pricing.new(-10, "USD", "per_session", nil)
      {:error, "Amount must be non-negative"}

      iex> Pricing.new(100, "INVALID", "per_session", nil)
      {:error, "Invalid currency: INVALID"}
  """
  @spec new(any(), any(), any(), any()) :: {:ok, t()} | {:error, String.t()}
  def new(amount, currency, unit, discount_amount) do
    with :ok <- validate_amount(amount),
         {:ok, decimal_amount} <- convert_to_decimal(amount, "Amount"),
         :ok <- validate_positive_amount(decimal_amount),
         :ok <- validate_currency(currency),
         normalized_currency = normalize_currency(currency),
         :ok <- validate_unit(unit),
         normalized_unit = normalize_unit(unit),
         {:ok, decimal_discount} <- process_discount(discount_amount),
         :ok <- validate_discount(decimal_amount, decimal_discount) do
      {:ok,
       %__MODULE__{
         amount: decimal_amount,
         currency: normalized_currency,
         unit: normalized_unit,
         discount_amount: decimal_discount
       }}
    end
  end

  @doc """
  Calculates the final price after applying discount.

  ## Parameters
    - pricing: The Pricing struct

  ## Returns
    - Decimal: The final price after discount

  ## Examples

      iex> {:ok, pricing} = Pricing.new(100, "USD", "per_session", nil)
      iex> Pricing.final_price(pricing)
      Decimal.new("100")

      iex> {:ok, pricing} = Pricing.new(100, "USD", "per_session", 20)
      iex> Pricing.final_price(pricing)
      Decimal.new("80")
  """
  @spec final_price(t()) :: Decimal.t()
  def final_price(%__MODULE__{amount: amount, discount_amount: nil}), do: amount

  def final_price(%__MODULE__{amount: amount, discount_amount: discount}) do
    Decimal.sub(amount, discount)
  end

  @doc """
  Calculates the discount as a percentage of the original price.

  ## Parameters
    - pricing: The Pricing struct

  ## Returns
    - Decimal | nil: The discount percentage, or nil if no discount

  ## Examples

      iex> {:ok, pricing} = Pricing.new(100, "USD", "per_session", nil)
      iex> Pricing.discount_percentage(pricing)
      nil

      iex> {:ok, pricing} = Pricing.new(100, "USD", "per_session", 25)
      iex> Pricing.discount_percentage(pricing)
      Decimal.new("25.00")
  """
  @spec discount_percentage(t()) :: Decimal.t() | nil
  def discount_percentage(%__MODULE__{discount_amount: nil}), do: nil

  def discount_percentage(%__MODULE__{amount: amount, discount_amount: discount}) do
    discount
    |> Decimal.div(amount)
    |> Decimal.mult(100)
    |> Decimal.round(2)
  end

  @doc """
  Checks if the pricing has a discount.

  ## Parameters
    - pricing: The Pricing struct

  ## Returns
    - boolean: true if discount exists and is greater than zero, false otherwise

  ## Examples

      iex> {:ok, pricing} = Pricing.new(100, "USD", "per_session", nil)
      iex> Pricing.has_discount?(pricing)
      false

      iex> {:ok, pricing} = Pricing.new(100, "USD", "per_session", 20)
      iex> Pricing.has_discount?(pricing)
      true

      iex> {:ok, pricing} = Pricing.new(100, "USD", "per_session", 0)
      iex> Pricing.has_discount?(pricing)
      false
  """
  @spec has_discount?(t()) :: boolean()
  def has_discount?(%__MODULE__{discount_amount: nil}), do: false

  def has_discount?(%__MODULE__{discount_amount: discount}) do
    Decimal.compare(discount, 0) == :gt
  end

  @doc """
  Formats the pricing for display.

  Returns a formatted string with currency symbol, amount, and unit.
  If a discount is present, shows the final price and original price.

  ## Parameters
    - pricing: The Pricing struct

  ## Returns
    - String: Formatted pricing display

  ## Examples

      iex> {:ok, pricing} = Pricing.new(100, "USD", "per_session", nil)
      iex> Pricing.format_display(pricing)
      "$100.00 per session"

      iex> {:ok, pricing} = Pricing.new(100, "USD", "per_session", 20)
      iex> Pricing.format_display(pricing)
      "$80.00 per session (was $100.00)"

      iex> {:ok, pricing} = Pricing.new(100, "EUR", "per_month", nil)
      iex> Pricing.format_display(pricing)
      "€100.00 per month"
  """
  @spec format_display(t()) :: String.t()
  def format_display(%__MODULE__{} = pricing) do
    symbol = Map.get(@currency_symbols, pricing.currency, pricing.currency)
    unit_text = Map.get(@unit_display, pricing.unit, pricing.unit)

    if has_discount?(pricing) do
      final = format_amount(final_price(pricing))
      original = format_amount(pricing.amount)
      "#{symbol}#{final} #{unit_text} (was #{symbol}#{original})"
    else
      amount_str = format_amount(pricing.amount)
      "#{symbol}#{amount_str} #{unit_text}"
    end
  end

  # Private helper functions

  defp validate_amount(nil), do: {:error, "Amount cannot be nil"}
  defp validate_amount(_amount), do: :ok

  defp convert_to_decimal(amount, field_name) do
    case Decimal.cast(amount) do
      {:ok, decimal} ->
        # Round floats to 2 decimal places, preserve integer precision
        rounded =
          if is_float(amount) do
            Decimal.round(decimal, 2)
          else
            decimal
          end

        {:ok, rounded}

      :error ->
        {:error, "#{field_name} must be a valid number"}
    end
  end

  defp validate_positive_amount(decimal_amount) do
    cond do
      Decimal.compare(decimal_amount, 0) == :lt ->
        {:error, "Amount must be non-negative"}

      Decimal.compare(decimal_amount, 0) == :eq ->
        {:error, "Amount must be greater than zero"}

      true ->
        :ok
    end
  end

  defp validate_currency(nil), do: {:error, "Currency cannot be nil"}

  defp validate_currency(currency) when is_binary(currency) do
    normalized = currency |> String.trim() |> String.upcase()

    cond do
      normalized == "" ->
        {:error, "Currency cannot be empty"}

      normalized not in @valid_currencies ->
        {:error, "Invalid currency: #{currency}"}

      true ->
        :ok
    end
  end

  defp normalize_currency(currency) do
    currency |> String.trim() |> String.upcase()
  end

  defp validate_unit(nil), do: {:error, "Unit cannot be nil"}

  defp validate_unit(unit) when is_binary(unit) do
    normalized = String.trim(unit)

    cond do
      normalized == "" ->
        {:error, "Unit cannot be empty"}

      normalized not in @valid_units ->
        {:error, "Invalid unit: #{unit}"}

      true ->
        :ok
    end
  end

  defp normalize_unit(unit) do
    String.trim(unit)
  end

  defp process_discount(nil), do: {:ok, nil}
  defp process_discount(0), do: {:ok, Decimal.new(0)}

  defp process_discount(discount) do
    convert_to_decimal(discount, "Discount")
  end

  defp validate_discount(_amount, nil), do: :ok

  defp validate_discount(amount, discount) when is_struct(discount, Decimal) do
    cond do
      Decimal.compare(discount, 0) == :lt ->
        {:error, "Discount must be non-negative"}

      Decimal.compare(discount, amount) in [:eq, :gt] ->
        {:error, "Discount cannot be equal to or greater than price"}

      true ->
        :ok
    end
  end

  defp format_amount(decimal) do
    # Format with exactly 2 decimal places
    decimal
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
    |> ensure_two_decimals()
  end

  defp ensure_two_decimals(str) do
    case String.split(str, ".") do
      [integer] -> "#{integer}.00"
      [integer, decimals] when byte_size(decimals) == 1 -> "#{integer}.#{decimals}0"
      [_integer, _decimals] = parts -> Enum.join(parts, ".")
    end
  end
end
