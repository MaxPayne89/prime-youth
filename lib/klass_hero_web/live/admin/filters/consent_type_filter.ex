defmodule KlassHeroWeb.Admin.Filters.ConsentTypeFilter do
  @moduledoc false

  use Backpex.Filters.Select

  alias KlassHero.Family.Domain.Models.Consent

  @impl Backpex.Filter
  def label, do: "Consent Type"

  @impl Backpex.Filters.Select
  def prompt, do: "All types..."

  @impl Backpex.Filters.Select
  def options(_assigns) do
    Consent.valid_consent_types()
    |> Enum.map(fn type -> {humanize_consent_type(type), type} end)
  end

  defp humanize_consent_type(type) do
    type
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
