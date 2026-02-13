defmodule KlassHero.Shared.SubscriptionTiers do
  @moduledoc """
  Shared vocabulary for subscription tier names, defaults, and validation.

  Lives in the Shared kernel so that both Identity (domain model validation)
  and Entitlements (limit lookups) can reference tier names without creating
  a cyclic dependency between contexts.
  """

  @parent_tiers [:explorer, :active]
  @provider_tiers [:starter, :professional, :business_plus]

  @doc """
  Returns the list of valid parent subscription tier atoms.

  ## Examples

      iex> KlassHero.Shared.SubscriptionTiers.parent_tiers()
      [:explorer, :active]
  """
  @spec parent_tiers() :: [atom()]
  def parent_tiers, do: @parent_tiers

  @doc """
  Returns the list of valid provider subscription tier atoms.

  ## Examples

      iex> KlassHero.Shared.SubscriptionTiers.provider_tiers()
      [:starter, :professional, :business_plus]
  """
  @spec provider_tiers() :: [atom()]
  def provider_tiers, do: @provider_tiers

  @doc """
  Checks if the given tier is a valid parent subscription tier.

  ## Examples

      iex> KlassHero.Shared.SubscriptionTiers.valid_parent_tier?(:explorer)
      true

      iex> KlassHero.Shared.SubscriptionTiers.valid_parent_tier?(:invalid)
      false
  """
  @spec valid_parent_tier?(term()) :: boolean()
  def valid_parent_tier?(tier) when is_atom(tier), do: tier in @parent_tiers
  def valid_parent_tier?(_), do: false

  @doc """
  Checks if the given tier is a valid provider subscription tier.

  ## Examples

      iex> KlassHero.Shared.SubscriptionTiers.valid_provider_tier?(:starter)
      true

      iex> KlassHero.Shared.SubscriptionTiers.valid_provider_tier?(:invalid)
      false
  """
  @spec valid_provider_tier?(term()) :: boolean()
  def valid_provider_tier?(tier) when is_atom(tier), do: tier in @provider_tiers
  def valid_provider_tier?(_), do: false

  @doc """
  Returns the default subscription tier for parents.

  ## Examples

      iex> KlassHero.Shared.SubscriptionTiers.default_parent_tier()
      :explorer
  """
  @spec default_parent_tier() :: atom()
  def default_parent_tier, do: :explorer

  @doc """
  Returns the default subscription tier for providers.

  ## Examples

      iex> KlassHero.Shared.SubscriptionTiers.default_provider_tier()
      :starter
  """
  @spec default_provider_tier() :: atom()
  def default_provider_tier, do: :starter
end
