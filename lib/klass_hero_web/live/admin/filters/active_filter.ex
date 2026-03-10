defmodule KlassHeroWeb.Admin.Filters.ActiveFilter do
  @moduledoc false

  use Backpex.Filters.Boolean

  import Ecto.Query

  @impl Backpex.Filter
  def label, do: "Active Status"

  @impl Backpex.Filters.Boolean
  def options(_assigns) do
    [
      %{label: "Active", key: "active", predicate: dynamic([x], x.active)},
      %{label: "Inactive", key: "inactive", predicate: dynamic([x], not x.active)}
    ]
  end
end
