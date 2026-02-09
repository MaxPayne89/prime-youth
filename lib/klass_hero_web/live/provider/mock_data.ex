defmodule KlassHeroWeb.Provider.MockData do
  @moduledoc """
  Temporary mock data for provider dashboard features not yet backed by real data.
  Remove this module once all dashboard sections use real database queries.
  """

  @doc """
  Returns placeholder stats until analytics features are implemented.
  """
  def stats do
    %{
      total_revenue: 12_500,
      active_bookings: 45,
      profile_views: 1_205,
      average_rating: 4.9
    }
  end
end
