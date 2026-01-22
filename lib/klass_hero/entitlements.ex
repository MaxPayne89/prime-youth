defmodule KlassHero.Entitlements do
  @moduledoc """
  Pure domain service for subscription tier entitlements.

  This module provides cross-context authorization checks based on subscription tiers.
  It contains no database dependencies and operates solely on domain entities.

  ## Parent Tiers

  | Tier       | Booking Cap | Free Cancellations | Progress Detail | Can Initiate Messaging |
  |------------|-------------|--------------------|-----------------|-----------------------|
  | `explorer` | 2/month     | 0                  | Basic           | No                    |
  | `active`   | Unlimited   | 1/month            | Detailed        | Yes                   |

  ## Provider Tiers

  | Tier            | Max Programs | Commission | Media Types              | Team Seats | Can Initiate Messaging |
  |-----------------|--------------|------------|--------------------------|------------|----------------------|
  | `starter`       | 2            | 18%        | Avatar only              | 1          | No                   |
  | `professional`  | 5            | 12%        | Avatar, Gallery, Video   | 1          | Yes                  |
  | `business_plus` | Unlimited    | 8%         | All (incl. Promotional)  | 3          | Yes                  |

  ## Usage

  The module accepts either domain entities or Scope structs:

      # With domain entity
      Entitlements.can_create_booking?(parent_profile, current_booking_count)

      # With scope
      Entitlements.can_initiate_messaging?(scope)
  """

  alias KlassHero.Accounts.Scope
  alias KlassHero.Identity.Domain.Models.{ParentProfile, ProviderProfile}

  @parent_tier_limits %{
    explorer: %{
      monthly_booking_cap: 2,
      free_cancellations: 0,
      progress_level: :basic,
      can_initiate_messaging: false
    },
    active: %{
      monthly_booking_cap: :unlimited,
      free_cancellations: 1,
      progress_level: :detailed,
      can_initiate_messaging: true
    }
  }

  @provider_tier_limits %{
    starter: %{
      max_programs: 2,
      commission_rate: 0.18,
      media: [:avatar],
      team_seats: 1,
      can_initiate_messaging: false
    },
    professional: %{
      max_programs: 5,
      commission_rate: 0.12,
      media: [:avatar, :gallery, :video],
      team_seats: 1,
      can_initiate_messaging: true
    },
    business_plus: %{
      max_programs: :unlimited,
      commission_rate: 0.08,
      media: [:avatar, :gallery, :video, :promotional],
      team_seats: 3,
      can_initiate_messaging: true
    }
  }

  # Parent entitlement functions

  @doc """
  Checks if a parent can create a new booking based on their tier's monthly cap.

  ## Examples

      iex> parent = %ParentProfile{subscription_tier: :explorer}
      iex> Entitlements.can_create_booking?(parent, 1)
      true

      iex> parent = %ParentProfile{subscription_tier: :explorer}
      iex> Entitlements.can_create_booking?(parent, 2)
      false

      iex> parent = %ParentProfile{subscription_tier: :active}
      iex> Entitlements.can_create_booking?(parent, 100)
      true
  """
  @spec can_create_booking?(ParentProfile.t(), non_neg_integer()) :: boolean()
  def can_create_booking?(%ParentProfile{subscription_tier: tier}, current_count) do
    tier
    |> get_parent_limit(:monthly_booking_cap)
    |> within_limit?(current_count)
  end

  @doc """
  Returns the monthly booking cap for a parent based on their tier.

  Returns `:unlimited` for tiers with no cap.

  ## Examples

      iex> parent = %ParentProfile{subscription_tier: :explorer}
      iex> Entitlements.monthly_booking_cap(parent)
      2

      iex> parent = %ParentProfile{subscription_tier: :active}
      iex> Entitlements.monthly_booking_cap(parent)
      :unlimited
  """
  @spec monthly_booking_cap(ParentProfile.t()) :: non_neg_integer() | :unlimited
  def monthly_booking_cap(%ParentProfile{subscription_tier: tier}) do
    get_parent_limit(tier, :monthly_booking_cap)
  end

  @doc """
  Returns the number of free cancellations per month for a parent based on their tier.

  ## Examples

      iex> parent = %ParentProfile{subscription_tier: :explorer}
      iex> Entitlements.free_cancellations_per_month(parent)
      0

      iex> parent = %ParentProfile{subscription_tier: :active}
      iex> Entitlements.free_cancellations_per_month(parent)
      1
  """
  @spec free_cancellations_per_month(ParentProfile.t()) :: non_neg_integer()
  def free_cancellations_per_month(%ParentProfile{subscription_tier: tier}) do
    get_parent_limit(tier, :free_cancellations)
  end

  @doc """
  Returns the progress detail level for a parent based on their tier.

  ## Examples

      iex> parent = %ParentProfile{subscription_tier: :explorer}
      iex> Entitlements.progress_detail_level(parent)
      :basic

      iex> parent = %ParentProfile{subscription_tier: :active}
      iex> Entitlements.progress_detail_level(parent)
      :detailed
  """
  @spec progress_detail_level(ParentProfile.t()) :: :basic | :detailed
  def progress_detail_level(%ParentProfile{subscription_tier: tier}) do
    get_parent_limit(tier, :progress_level)
  end

  # Provider entitlement functions

  @doc """
  Checks if a provider can create a new program based on their tier's program limit.

  ## Examples

      iex> provider = %ProviderProfile{subscription_tier: :starter}
      iex> Entitlements.can_create_program?(provider, 1)
      true

      iex> provider = %ProviderProfile{subscription_tier: :starter}
      iex> Entitlements.can_create_program?(provider, 2)
      false

      iex> provider = %ProviderProfile{subscription_tier: :business_plus}
      iex> Entitlements.can_create_program?(provider, 100)
      true
  """
  @spec can_create_program?(ProviderProfile.t(), non_neg_integer()) :: boolean()
  def can_create_program?(%ProviderProfile{subscription_tier: tier}, current_count) do
    tier
    |> get_provider_limit(:max_programs)
    |> within_limit?(current_count)
  end

  @doc """
  Returns the commission rate for a provider based on their tier.

  ## Examples

      iex> provider = %ProviderProfile{subscription_tier: :starter}
      iex> Entitlements.commission_rate(provider)
      0.18

      iex> provider = %ProviderProfile{subscription_tier: :professional}
      iex> Entitlements.commission_rate(provider)
      0.12

      iex> provider = %ProviderProfile{subscription_tier: :business_plus}
      iex> Entitlements.commission_rate(provider)
      0.08
  """
  @spec commission_rate(ProviderProfile.t()) :: float()
  def commission_rate(%ProviderProfile{subscription_tier: tier}) do
    get_provider_limit(tier, :commission_rate)
  end

  @doc """
  Returns the list of allowed media types for a provider based on their tier.

  ## Examples

      iex> provider = %ProviderProfile{subscription_tier: :starter}
      iex> Entitlements.media_entitlements(provider)
      [:avatar]

      iex> provider = %ProviderProfile{subscription_tier: :professional}
      iex> Entitlements.media_entitlements(provider)
      [:avatar, :gallery, :video]

      iex> provider = %ProviderProfile{subscription_tier: :business_plus}
      iex> Entitlements.media_entitlements(provider)
      [:avatar, :gallery, :video, :promotional]
  """
  @spec media_entitlements(ProviderProfile.t()) :: [atom()]
  def media_entitlements(%ProviderProfile{subscription_tier: tier}) do
    get_provider_limit(tier, :media)
  end

  @doc """
  Returns the maximum number of programs a provider can create based on their tier.

  Returns `:unlimited` for tiers with no limit.

  ## Examples

      iex> provider = %ProviderProfile{subscription_tier: :starter}
      iex> Entitlements.max_programs(provider)
      2

      iex> provider = %ProviderProfile{subscription_tier: :professional}
      iex> Entitlements.max_programs(provider)
      5

      iex> provider = %ProviderProfile{subscription_tier: :business_plus}
      iex> Entitlements.max_programs(provider)
      :unlimited
  """
  @spec max_programs(ProviderProfile.t()) :: non_neg_integer() | :unlimited
  def max_programs(%ProviderProfile{subscription_tier: tier}) do
    get_provider_limit(tier, :max_programs)
  end

  @doc """
  Returns the number of team seats allowed for a provider based on their tier.

  ## Examples

      iex> provider = %ProviderProfile{subscription_tier: :starter}
      iex> Entitlements.team_seats_allowed(provider)
      1

      iex> provider = %ProviderProfile{subscription_tier: :professional}
      iex> Entitlements.team_seats_allowed(provider)
      1

      iex> provider = %ProviderProfile{subscription_tier: :business_plus}
      iex> Entitlements.team_seats_allowed(provider)
      3
  """
  @spec team_seats_allowed(ProviderProfile.t()) :: non_neg_integer()
  def team_seats_allowed(%ProviderProfile{subscription_tier: tier}) do
    get_provider_limit(tier, :team_seats)
  end

  # Scope-based entitlement functions

  @doc """
  Checks if a scope can initiate messaging based on the associated profile's tier.

  Works with both parent and provider profiles. If both are present, returns true
  if either profile has messaging rights.

  ## Examples

      iex> scope = %Scope{parent: %ParentProfile{subscription_tier: :explorer}}
      iex> Entitlements.can_initiate_messaging?(scope)
      false

      iex> scope = %Scope{parent: %ParentProfile{subscription_tier: :active}}
      iex> Entitlements.can_initiate_messaging?(scope)
      true

      iex> scope = %Scope{provider: %ProviderProfile{subscription_tier: :professional}}
      iex> Entitlements.can_initiate_messaging?(scope)
      true
  """
  @spec can_initiate_messaging?(Scope.t()) :: boolean()
  def can_initiate_messaging?(%Scope{parent: parent, provider: provider}) do
    parent_can_message?(parent) or provider_can_message?(provider)
  end

  # Tier validation functions (replacing separate type modules)

  @doc """
  Returns the list of valid parent subscription tier atoms.

  ## Examples

      iex> Entitlements.parent_tiers()
      [:explorer, :active]
  """
  @spec parent_tiers() :: [atom()]
  def parent_tiers, do: Map.keys(@parent_tier_limits)

  @doc """
  Returns the list of valid provider subscription tier atoms.

  ## Examples

      iex> Entitlements.provider_tiers()
      [:starter, :professional, :business_plus]
  """
  @spec provider_tiers() :: [atom()]
  def provider_tiers, do: Map.keys(@provider_tier_limits)

  @doc """
  Checks if the given tier is a valid parent subscription tier.

  ## Examples

      iex> Entitlements.valid_parent_tier?(:explorer)
      true

      iex> Entitlements.valid_parent_tier?(:invalid)
      false
  """
  @spec valid_parent_tier?(term()) :: boolean()
  def valid_parent_tier?(tier) when is_atom(tier), do: Map.has_key?(@parent_tier_limits, tier)
  def valid_parent_tier?(_), do: false

  @doc """
  Checks if the given tier is a valid provider subscription tier.

  ## Examples

      iex> Entitlements.valid_provider_tier?(:starter)
      true

      iex> Entitlements.valid_provider_tier?(:invalid)
      false
  """
  @spec valid_provider_tier?(term()) :: boolean()
  def valid_provider_tier?(tier) when is_atom(tier), do: Map.has_key?(@provider_tier_limits, tier)
  def valid_provider_tier?(_), do: false

  @doc """
  Returns the default subscription tier for parents.

  ## Examples

      iex> Entitlements.default_parent_tier()
      :explorer
  """
  @spec default_parent_tier() :: atom()
  def default_parent_tier, do: :explorer

  @doc """
  Returns the default subscription tier for providers.

  ## Examples

      iex> Entitlements.default_provider_tier()
      :starter
  """
  @spec default_provider_tier() :: atom()
  def default_provider_tier, do: :starter

  # Tier info functions (for UI)

  @doc """
  Returns all entitlement information for a parent tier.

  ## Examples

      iex> Entitlements.parent_tier_info(:explorer)
      %{monthly_booking_cap: 2, free_cancellations: 0, progress_level: :basic, can_initiate_messaging: false}
  """
  @spec parent_tier_info(atom()) :: map() | nil
  def parent_tier_info(tier) do
    Map.get(@parent_tier_limits, tier)
  end

  @doc """
  Returns all entitlement information for a provider tier.

  ## Examples

      iex> Entitlements.provider_tier_info(:starter)
      %{max_programs: 2, commission_rate: 0.18, media: [:avatar], team_seats: 1, can_initiate_messaging: false}
  """
  @spec provider_tier_info(atom()) :: map() | nil
  def provider_tier_info(tier) do
    Map.get(@provider_tier_limits, tier)
  end

  @doc """
  Returns a list of all parent tiers with their entitlements.

  ## Examples

      iex> Entitlements.all_parent_tiers()
      [explorer: %{...}, active: %{...}]
  """
  @spec all_parent_tiers() :: keyword()
  def all_parent_tiers, do: Map.to_list(@parent_tier_limits)

  @doc """
  Returns a list of all provider tiers with their entitlements.

  ## Examples

      iex> Entitlements.all_provider_tiers()
      [starter: %{...}, professional: %{...}, business_plus: %{...}]
  """
  @spec all_provider_tiers() :: keyword()
  def all_provider_tiers, do: Map.to_list(@provider_tier_limits)

  # Private helpers

  defp within_limit?(:unlimited, _count), do: true
  defp within_limit?(limit, count) when is_integer(limit), do: count < limit

  defp parent_can_message?(nil), do: false

  defp parent_can_message?(%{subscription_tier: tier}),
    do: get_parent_limit(tier, :can_initiate_messaging)

  defp provider_can_message?(nil), do: false

  defp provider_can_message?(%{subscription_tier: tier}),
    do: get_provider_limit(tier, :can_initiate_messaging)

  defp get_parent_limit(tier, key) do
    tier = tier || :explorer
    get_in(@parent_tier_limits, [tier, key])
  end

  defp get_provider_limit(tier, key) do
    tier = tier || :starter
    get_in(@provider_tier_limits, [tier, key])
  end
end
