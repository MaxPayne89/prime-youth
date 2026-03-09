defmodule KlassHeroWeb.Admin.Filters.VerifiedFilter do
  @moduledoc false

  use Backpex.Filters.Boolean

  import Ecto.Query

  @impl Backpex.Filter
  def label, do: "Verification Status"

  @impl Backpex.Filters.Boolean
  def options(_assigns) do
    [
      %{label: "Verified", key: "verified", predicate: dynamic([x], x.verified)},
      %{label: "Not Verified", key: "not_verified", predicate: dynamic([x], not x.verified)}
    ]
  end
end
