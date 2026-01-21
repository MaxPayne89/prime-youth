defmodule KlassHero.Enrollment.Application.UseCases.CalculateEnrollmentFees do
  @moduledoc """
  Use case for calculating enrollment fees including VAT and card processing fees.
  """

  alias KlassHero.Enrollment.Domain.Models.FeeCalculation

  @type params :: %{
          weekly_fee: number(),
          registration_fee: number(),
          vat_rate: number(),
          card_fee: number(),
          payment_method: String.t()
        }

  @spec execute(params()) :: {:ok, FeeCalculation.t()}
  def execute(%{
        weekly_fee: weekly_fee,
        registration_fee: registration_fee,
        vat_rate: vat_rate,
        card_fee: card_fee,
        payment_method: payment_method
      })
      when is_number(weekly_fee) and is_number(registration_fee) and is_number(vat_rate) and
             is_number(card_fee) and is_binary(payment_method) do
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
