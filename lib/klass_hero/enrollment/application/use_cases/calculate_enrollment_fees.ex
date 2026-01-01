defmodule KlassHero.Enrollment.Application.UseCases.CalculateEnrollmentFees do
  @moduledoc """
  Use case for calculating enrollment fees including VAT and card processing fees.
  """

  alias KlassHero.Enrollment.Domain.Models.FeeCalculation

  def execute(%{
        weekly_fee: weekly_fee,
        registration_fee: registration_fee,
        vat_rate: vat_rate,
        card_fee: card_fee,
        payment_method: payment_method
      }) do
    subtotal = weekly_fee + registration_fee
    vat_amount = subtotal * vat_rate
    card_fee_amount = if payment_method == "card", do: card_fee, else: 0.0
    total = subtotal + vat_amount + card_fee_amount

    {:ok,
     %FeeCalculation{
       subtotal: subtotal,
       vat_amount: vat_amount,
       card_fee_amount: card_fee_amount,
       total: total
     }}
  end
end
