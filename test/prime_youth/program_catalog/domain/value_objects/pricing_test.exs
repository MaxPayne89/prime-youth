defmodule PrimeYouth.ProgramCatalog.Domain.ValueObjects.PricingTest do
  @moduledoc """
  Tests for Pricing value object.

  Tests cover:
  - Price amount validation
  - Currency support
  - Price unit (per_session, per_month, per_program)
  - Discount calculation
  - Display formatting
  """

  use ExUnit.Case, async: true

  alias PrimeYouth.ProgramCatalog.Domain.ValueObjects.Pricing

  describe "new/4" do
    test "creates pricing with valid values" do
      assert {:ok, pricing} = Pricing.new(100.00, "USD", "per_session", nil)
      assert pricing.amount == Decimal.new("100.00")
      assert pricing.currency == "USD"
      assert pricing.unit == "per_session"
      assert pricing.discount_amount == nil
    end

    test "creates pricing with discount" do
      assert {:ok, pricing} = Pricing.new(100.00, "USD", "per_session", 20.00)
      assert pricing.amount == Decimal.new("100.00")
      assert pricing.discount_amount == Decimal.new("20.00")
    end

    test "accepts integer amount" do
      assert {:ok, pricing} = Pricing.new(100, "USD", "per_session", nil)
      assert pricing.amount == Decimal.new("100")
    end

    test "accepts string amount" do
      assert {:ok, pricing} = Pricing.new("99.99", "USD", "per_session", nil)
      assert pricing.amount == Decimal.new("99.99")
    end

    test "accepts all valid price units" do
      units = ["per_session", "per_month", "per_program"]

      for unit <- units do
        assert {:ok, _pricing} = Pricing.new(100, "USD", unit, nil)
      end
    end

    test "accepts all valid currencies" do
      currencies = ["USD", "EUR", "GBP", "CAD"]

      for currency <- currencies do
        assert {:ok, _pricing} = Pricing.new(100, currency, "per_session", nil)
      end
    end

    test "rejects negative amount" do
      assert {:error, "Amount must be non-negative"} = Pricing.new(-10, "USD", "per_session", nil)
    end

    test "rejects zero amount" do
      assert {:error, "Amount must be greater than zero"} =
               Pricing.new(0, "USD", "per_session", nil)
    end

    test "rejects nil amount" do
      assert {:error, "Amount cannot be nil"} = Pricing.new(nil, "USD", "per_session", nil)
    end

    test "rejects invalid amount format" do
      assert {:error, "Amount must be a valid number"} =
               Pricing.new("invalid", "USD", "per_session", nil)
    end

    test "rejects nil currency" do
      assert {:error, "Currency cannot be nil"} = Pricing.new(100, nil, "per_session", nil)
    end

    test "rejects empty currency" do
      assert {:error, "Currency cannot be empty"} = Pricing.new(100, "", "per_session", nil)
    end

    test "rejects invalid currency" do
      assert {:error, "Invalid currency: INVALID"} =
               Pricing.new(100, "INVALID", "per_session", nil)
    end

    test "rejects nil unit" do
      assert {:error, "Unit cannot be nil"} = Pricing.new(100, "USD", nil, nil)
    end

    test "rejects empty unit" do
      assert {:error, "Unit cannot be empty"} = Pricing.new(100, "USD", "", nil)
    end

    test "rejects invalid unit" do
      assert {:error, "Invalid unit: invalid"} = Pricing.new(100, "USD", "invalid", nil)
    end

    test "rejects discount equal to price" do
      assert {:error, "Discount cannot be equal to or greater than price"} =
               Pricing.new(100, "USD", "per_session", 100)
    end

    test "rejects discount greater than price" do
      assert {:error, "Discount cannot be equal to or greater than price"} =
               Pricing.new(100, "USD", "per_session", 150)
    end

    test "rejects negative discount" do
      assert {:error, "Discount must be non-negative"} =
               Pricing.new(100, "USD", "per_session", -10)
    end

    test "normalizes currency to uppercase" do
      assert {:ok, pricing} = Pricing.new(100, "usd", "per_session", nil)
      assert pricing.currency == "USD"
    end

    test "trims whitespace from currency" do
      assert {:ok, pricing} = Pricing.new(100, "  USD  ", "per_session", nil)
      assert pricing.currency == "USD"
    end

    test "trims whitespace from unit" do
      assert {:ok, pricing} = Pricing.new(100, "USD", "  per_session  ", nil)
      assert pricing.unit == "per_session"
    end
  end

  describe "final_price/1" do
    test "returns original price when no discount" do
      {:ok, pricing} = Pricing.new(100, "USD", "per_session", nil)
      assert Pricing.final_price(pricing) == Decimal.new("100")
    end

    test "calculates final price with discount" do
      {:ok, pricing} = Pricing.new(100, "USD", "per_session", 20)
      assert Pricing.final_price(pricing) == Decimal.new("80")
    end

    test "calculates final price with decimal discount" do
      {:ok, pricing} = Pricing.new(99.99, "USD", "per_session", 9.99)
      assert Pricing.final_price(pricing) == Decimal.new("90.00")
    end

    test "handles zero discount" do
      {:ok, pricing} = Pricing.new(100, "USD", "per_session", 0)
      assert Pricing.final_price(pricing) == Decimal.new("100")
    end
  end

  describe "discount_percentage/1" do
    test "returns nil when no discount" do
      {:ok, pricing} = Pricing.new(100, "USD", "per_session", nil)
      assert Pricing.discount_percentage(pricing) == nil
    end

    test "calculates discount percentage" do
      {:ok, pricing} = Pricing.new(100, "USD", "per_session", 25)
      assert Pricing.discount_percentage(pricing) == Decimal.new("25.00")
    end

    test "calculates decimal discount percentage" do
      {:ok, pricing} = Pricing.new(100, "USD", "per_session", 33.33)
      # Allow small rounding differences
      result = Pricing.discount_percentage(pricing)
      assert Decimal.compare(result, Decimal.new("33.32")) in [:eq, :gt]
      assert Decimal.compare(result, Decimal.new("33.34")) in [:eq, :lt]
    end

    test "handles zero discount" do
      {:ok, pricing} = Pricing.new(100, "USD", "per_session", 0)
      assert Pricing.discount_percentage(pricing) == Decimal.new("0.00")
    end
  end

  describe "format_display/1" do
    test "formats USD pricing without discount" do
      {:ok, pricing} = Pricing.new(100, "USD", "per_session", nil)
      assert Pricing.format_display(pricing) == "$100.00 per session"
    end

    test "formats USD pricing with discount" do
      {:ok, pricing} = Pricing.new(100, "USD", "per_session", 20)
      assert Pricing.format_display(pricing) == "$80.00 per session (was $100.00)"
    end

    test "formats per_month unit" do
      {:ok, pricing} = Pricing.new(500, "USD", "per_month", nil)
      assert Pricing.format_display(pricing) == "$500.00 per month"
    end

    test "formats per_program unit" do
      {:ok, pricing} = Pricing.new(1200, "USD", "per_program", nil)
      assert Pricing.format_display(pricing) == "$1200.00 per program"
    end

    test "formats EUR currency" do
      {:ok, pricing} = Pricing.new(100, "EUR", "per_session", nil)
      assert Pricing.format_display(pricing) == "€100.00 per session"
    end

    test "formats GBP currency" do
      {:ok, pricing} = Pricing.new(100, "GBP", "per_session", nil)
      assert Pricing.format_display(pricing) == "£100.00 per session"
    end

    test "formats CAD currency" do
      {:ok, pricing} = Pricing.new(100, "CAD", "per_session", nil)
      assert Pricing.format_display(pricing) == "CA$100.00 per session"
    end

    test "formats decimal amounts" do
      {:ok, pricing} = Pricing.new(99.99, "USD", "per_session", nil)
      assert Pricing.format_display(pricing) == "$99.99 per session"
    end

    test "formats with discount showing savings" do
      {:ok, pricing} = Pricing.new(150, "USD", "per_month", 30)
      assert Pricing.format_display(pricing) == "$120.00 per month (was $150.00)"
    end
  end

  describe "has_discount?/1" do
    test "returns false when no discount" do
      {:ok, pricing} = Pricing.new(100, "USD", "per_session", nil)
      refute Pricing.has_discount?(pricing)
    end

    test "returns true when discount present" do
      {:ok, pricing} = Pricing.new(100, "USD", "per_session", 20)
      assert Pricing.has_discount?(pricing)
    end

    test "returns false when discount is zero" do
      {:ok, pricing} = Pricing.new(100, "USD", "per_session", 0)
      refute Pricing.has_discount?(pricing)
    end
  end

  describe "value equality" do
    test "pricing with same values are equal" do
      {:ok, price1} = Pricing.new(100, "USD", "per_session", nil)
      {:ok, price2} = Pricing.new(100, "USD", "per_session", nil)

      assert Decimal.equal?(price1.amount, price2.amount)
      assert price1.currency == price2.currency
      assert price1.unit == price2.unit
    end

    test "pricing with different amounts are not equal" do
      {:ok, price1} = Pricing.new(100, "USD", "per_session", nil)
      {:ok, price2} = Pricing.new(200, "USD", "per_session", nil)

      refute Decimal.equal?(price1.amount, price2.amount)
    end
  end
end
