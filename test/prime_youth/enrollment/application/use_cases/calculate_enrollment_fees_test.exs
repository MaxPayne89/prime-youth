defmodule PrimeYouth.Enrollment.Application.UseCases.CalculateEnrollmentFeesTest do
  use ExUnit.Case, async: true

  alias PrimeYouth.Enrollment.Application.UseCases.CalculateEnrollmentFees
  alias PrimeYouth.Enrollment.Domain.Models.FeeCalculation

  describe "execute/1" do
    test "calculates fees correctly for card payment" do
      params = %{
        weekly_fee: 45.00,
        registration_fee: 25.00,
        vat_rate: 0.19,
        card_fee: 2.50,
        payment_method: "card"
      }

      {:ok, result} = CalculateEnrollmentFees.execute(params)

      assert %FeeCalculation{} = result
      assert result.subtotal == 70.00
      assert result.vat_amount == 13.30
      assert result.card_fee_amount == 2.50
      assert result.total == 85.80
    end

    test "excludes card fee for transfer payment" do
      params = %{
        weekly_fee: 45.00,
        registration_fee: 25.00,
        vat_rate: 0.19,
        card_fee: 2.50,
        payment_method: "transfer"
      }

      {:ok, result} = CalculateEnrollmentFees.execute(params)

      assert result.card_fee_amount == 0.0
      assert result.total == 83.30
    end

    test "calculates VAT correctly" do
      params = %{
        weekly_fee: 100.00,
        registration_fee: 0.00,
        vat_rate: 0.19,
        card_fee: 0.00,
        payment_method: "transfer"
      }

      {:ok, result} = CalculateEnrollmentFees.execute(params)

      assert result.subtotal == 100.00
      assert result.vat_amount == 19.00
      assert result.total == 119.00
    end

    test "total sums all components correctly" do
      params = %{
        weekly_fee: 50.00,
        registration_fee: 10.00,
        vat_rate: 0.10,
        card_fee: 5.00,
        payment_method: "card"
      }

      {:ok, result} = CalculateEnrollmentFees.execute(params)

      expected_subtotal = 60.00
      expected_vat = 6.00
      expected_card_fee = 5.00
      expected_total = expected_subtotal + expected_vat + expected_card_fee

      assert result.subtotal == expected_subtotal
      assert result.vat_amount == expected_vat
      assert result.card_fee_amount == expected_card_fee
      assert result.total == expected_total
    end
  end
end
