defmodule KlassHeroWeb.Admin.Filters.ConsentStatusFilter do
  @moduledoc false

  use Backpex.Filters.Select

  import Ecto.Query

  @impl Backpex.Filter
  def label, do: "Status"

  @impl Backpex.Filters.Select
  def prompt, do: "All statuses..."

  @impl Backpex.Filters.Select
  def options(_assigns) do
    [
      {"Active", "active"},
      {"Withdrawn", "withdrawn"}
    ]
  end

  # Trigger: default Select filter uses equality on the attribute column
  # Why: status is derived from withdrawn_at being NULL or NOT NULL, not a direct field value
  # Outcome: custom WHERE clause checking withdrawn_at nullability
  @impl Backpex.Filter
  def query(query, _attribute, "active", _assigns) do
    where(query, [x], is_nil(x.withdrawn_at))
  end

  @impl Backpex.Filter
  def query(query, _attribute, "withdrawn", _assigns) do
    where(query, [x], not is_nil(x.withdrawn_at))
  end

  @impl Backpex.Filter
  def query(query, _attribute, _value, _assigns), do: query
end
