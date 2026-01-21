defmodule KlassHero.Enrollment.Domain.Models.FeeCalculation do
  @moduledoc """
  Value object representing calculated enrollment fees.
  """

  @type t :: %__MODULE__{
          subtotal: number(),
          vat_amount: number(),
          card_fee_amount: number(),
          total: number()
        }

  @enforce_keys [:subtotal, :vat_amount, :card_fee_amount, :total]
  defstruct [:subtotal, :vat_amount, :card_fee_amount, :total]
end
