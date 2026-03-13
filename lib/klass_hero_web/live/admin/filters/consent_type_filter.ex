defmodule KlassHeroWeb.Admin.Filters.ConsentTypeFilter do
  @moduledoc false

  use Backpex.Filters.Select

  alias KlassHero.Family.Domain.Models.Consent
  alias KlassHeroWeb.Admin.ConsentLive

  @impl Backpex.Filter
  def label, do: "Consent Type"

  @impl Backpex.Filters.Select
  def prompt, do: "All types..."

  @impl Backpex.Filters.Select
  def options(_assigns) do
    Consent.valid_consent_types()
    |> Enum.map(fn type -> {ConsentLive.humanize_consent_type(type), type} end)
  end
end
