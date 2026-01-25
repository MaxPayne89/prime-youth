defmodule KlassHeroWeb.Presenters.ProviderPresenter do
  @moduledoc """
  Presentation layer for transforming Provider domain models to UI-ready formats.

  This module follows the DDD/Ports & Adapters pattern by keeping presentation
  concerns in the web layer while the domain model stays pure.

  ## Usage

      alias KlassHeroWeb.Presenters.ProviderPresenter

      # For dashboard business card
      business = ProviderPresenter.to_business_view(provider)
  """

  use Gettext, backend: KlassHeroWeb.Gettext

  alias KlassHero.Entitlements
  alias KlassHero.Identity.Domain.Models.ProviderProfile

  @doc """
  Transforms a Provider domain model to business view format.

  Used for the provider dashboard header and business profile card.

  Returns a map with: id, name, tagline, plan, plan_label, verified,
  verification_badges, program_slots_used, program_slots_total, initials
  """
  @spec to_business_view(ProviderProfile.t()) :: map()
  def to_business_view(%ProviderProfile{} = provider) do
    tier = provider.subscription_tier || Entitlements.default_provider_tier()
    tier_info = Entitlements.provider_tier_info(tier)

    %{
      id: provider.id,
      name: provider.business_name,
      tagline: provider.description,
      plan: tier,
      plan_label: tier_label(tier),
      verified: provider.verified || false,
      verification_badges: build_verification_badges(provider),
      program_slots_used: 0,
      program_slots_total: tier_info[:max_programs],
      initials: build_initials(provider.business_name)
    }
  end

  @doc """
  Converts a subscription tier atom to a human-readable label.
  """
  @spec tier_label(atom()) :: String.t()
  def tier_label(:starter), do: gettext("Starter Plan")
  def tier_label(:professional), do: gettext("Professional Plan")
  def tier_label(:business_plus), do: gettext("Business Plus Plan")
  def tier_label(_), do: gettext("Starter Plan")

  @doc """
  Builds a list of verification badges for display.

  Returns a list of maps with :key and :label for each badge.
  """
  @spec build_verification_badges(ProviderProfile.t()) :: [map()]
  def build_verification_badges(%ProviderProfile{verified: true}) do
    [
      %{key: :business_registration, label: gettext("Business Registration")}
    ]
  end

  def build_verification_badges(_provider), do: []

  @doc """
  Builds initials from a business name for avatar display.

  Takes the first letter of the first two words and uppercases them.
  Returns "?" if name is nil.
  """
  @spec build_initials(String.t() | nil) :: String.t()
  def build_initials(nil), do: "?"

  def build_initials(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end
end
