defmodule KlassHero.Enrollment.Application.UseCases.CountMonthlyBookings do
  @moduledoc """
  Use case for counting a parent's active enrollments within the current month.

  This is used by the entitlements system to enforce monthly booking limits
  for subscription tiers.

  ## Counting Logic

  - Only counts active enrollments (status: pending or confirmed)
  - Date range is determined by the enrolled_at timestamp
  - Default range is the current calendar month (1st to last day)
  """

  require Logger

  @doc """
  Counts active enrollments for a parent in a given month.

  Parameters:
  - parent_id: The parent's ID
  - month: Optional Date representing the month (defaults to current month)

  Returns non-negative integer count.
  """
  @spec execute(binary(), Date.t() | nil) :: non_neg_integer()
  def execute(parent_id, month \\ nil) when is_binary(parent_id) do
    {start_date, end_date} = get_month_range(month)

    Logger.debug("[Enrollment.CountMonthlyBookings] Counting bookings",
      parent_id: parent_id,
      start_date: start_date,
      end_date: end_date
    )

    repository().count_monthly_bookings(parent_id, start_date, end_date)
  end

  defp get_month_range(nil) do
    today = Date.utc_today()
    get_month_range(today)
  end

  defp get_month_range(%Date{} = date) do
    start_date = Date.beginning_of_month(date)
    end_date = Date.end_of_month(date)
    {start_date, end_date}
  end

  defp repository do
    Application.get_env(:klass_hero, :enrollment)[:for_managing_enrollments]
  end
end
