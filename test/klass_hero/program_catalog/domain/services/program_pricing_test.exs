defmodule KlassHero.ProgramCatalog.Domain.Services.ProgramPricingTest do
  use ExUnit.Case, async: true

  alias KlassHero.ProgramCatalog.Domain.Services.ProgramPricing

  describe "format_price/1" do
    test "formats Decimal value with currency symbol" do
      assert ProgramPricing.format_price(Decimal.new("45.00")) == "€45.00"
    end

    test "formats integer with currency symbol and two decimal places" do
      assert ProgramPricing.format_price(100) == "€100.00"
    end

    test "formats float with currency symbol and two decimal places" do
      assert ProgramPricing.format_price(45.50) == "€45.50"
    end

    test "returns N/A for nil price" do
      assert ProgramPricing.format_price(nil) == "N/A"
    end

    test "formats zero Decimal correctly" do
      assert ProgramPricing.format_price(Decimal.new("0.00")) == "€0.00"
    end
  end

  describe "default_currency/0" do
    test "returns euro symbol" do
      assert ProgramPricing.default_currency() == "€"
    end
  end
end
