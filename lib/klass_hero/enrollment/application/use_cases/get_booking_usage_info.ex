defmodule KlassHero.Enrollment.Application.UseCases.GetBookingUsageInfo do
  @moduledoc """
  Use case for retrieving booking usage information for a parent.

  This encapsulates the logic for fetching booking limits, current usage,
  and remaining capacity based on the parent's subscription tier.

  ## Returns

  On success, returns a map containing:
  - `parent_id` - The parent's UUID
  - `tier` - The subscription tier atom (:explorer or :active)
  - `cap` - The monthly booking cap (integer or :unlimited)
  - `used` - Number of bookings used this month
  - `remaining` - Number of bookings remaining (:unlimited or integer >= 0)
  """

  alias KlassHero.Enrollment
  alias KlassHero.Entitlements
  alias KlassHero.Identity

  require Logger

  @doc """
  Retrieves booking usage information for a parent identified by their identity ID.

  ## Parameters

  - `identity_id` - The user's identity ID (from authentication)

  ## Returns

  - `{:ok, info}` - Map with booking usage information
  - `{:error, :no_parent_profile}` - No parent profile exists for this identity
  """
  @spec execute(String.t()) :: {:ok, map()} | {:error, :no_parent_profile}
  def execute(identity_id) when is_binary(identity_id) do
    case Identity.get_parent_by_identity(identity_id) do
      {:ok, parent} ->
        {:ok, build_usage_info(parent)}

      {:error, :not_found} ->
        {:error, :no_parent_profile}
    end
  end

  defp build_usage_info(parent) do
    cap = Entitlements.monthly_booking_cap(parent)
    used = Enrollment.count_monthly_bookings(parent.id)
    remaining = calculate_remaining(cap, used)

    Logger.debug("[Enrollment.GetBookingUsageInfo] Booking usage info",
      parent_id: parent.id,
      tier: parent.subscription_tier,
      cap: cap,
      used: used,
      remaining: remaining
    )

    %{
      parent_id: parent.id,
      tier: parent.subscription_tier,
      cap: cap,
      used: used,
      remaining: remaining
    }
  end

  defp calculate_remaining(:unlimited, _used), do: :unlimited
  defp calculate_remaining(cap, used), do: max(0, cap - used)
end
