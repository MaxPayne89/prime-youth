defmodule KlassHero.Enrollment.Domain.Models.FeeCalculation do
  @moduledoc """
  Value object representing calculated enrollment fees.
  """

  @enforce_keys [:subtotal, :vat_amount, :card_fee_amount, :total]
  defstruct [:subtotal, :vat_amount, :card_fee_amount, :total]
end
