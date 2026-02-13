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

  The module accepts any map with a `:subscription_tier` key, or a scope map
  with `:parent` and/or `:provider` keys:

      # With domain entity (struct or map)
      Entitlements.can_create_booking?(parent_profile, current_booking_count)

      # With scope
      Entitlements.can_initiate_messaging?(scope)
  """

  use Boundary,
    top_level?: true,
    deps: [KlassHero.Shared],
    exports: []

  alias KlassHero.Shared.SubscriptionTiers

  @type tier_holder :: %{subscription_tier: atom()}

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

      iex> Entitlements.can_create_booking?(%{subscription_tier: :explorer}, 1)
      true

      iex> Entitlements.can_create_booking?(%{subscription_tier: :explorer}, 2)
      false

      iex> Entitlements.can_create_booking?(%{subscription_tier: :active}, 100)
      true
  """
  @spec can_create_booking?(tier_holder(), non_neg_integer()) :: boolean()
  def can_create_booking?(%{subscription_tier: tier}, current_count) do
    tier
    |> get_parent_limit(:monthly_booking_cap)
    |> within_limit?(current_count)
  end

  @doc """
  Returns the monthly booking cap for a parent based on their tier.

  Returns `:unlimited` for tiers with no cap.

  ## Examples

      iex> Entitlements.monthly_booking_cap(%{subscription_tier: :explorer})
      2

      iex> Entitlements.monthly_booking_cap(%{subscription_tier: :active})
      :unlimited
  """
  @spec monthly_booking_cap(tier_holder()) :: non_neg_integer() | :unlimited
  def monthly_booking_cap(%{subscription_tier: tier}) do
    get_parent_limit(tier, :monthly_booking_cap)
  end

  @doc """
  Returns the number of free cancellations per month for a parent based on their tier.

  ## Examples

      iex> Entitlements.free_cancellations_per_month(%{subscription_tier: :explorer})
      0

      iex> Entitlements.free_cancellations_per_month(%{subscription_tier: :active})
      1
  """
  @spec free_cancellations_per_month(tier_holder()) :: non_neg_integer()
  def free_cancellations_per_month(%{subscription_tier: tier}) do
    get_parent_limit(tier, :free_cancellations)
  end

  @doc """
  Returns the progress detail level for a parent based on their tier.

  ## Examples

      iex> Entitlements.progress_detail_level(%{subscription_tier: :explorer})
      :basic

      iex> Entitlements.progress_detail_level(%{subscription_tier: :active})
      :detailed
  """
  @spec progress_detail_level(tier_holder()) :: :basic | :detailed
  def progress_detail_level(%{subscription_tier: tier}) do
    get_parent_limit(tier, :progress_level)
  end

  # Provider entitlement functions

  @doc """
  Checks if a provider can create a new program based on their tier's program limit.

  ## Examples

      iex> Entitlements.can_create_program?(%{subscription_tier: :starter}, 1)
      true

      iex> Entitlements.can_create_program?(%{subscription_tier: :starter}, 2)
      false

      iex> Entitlements.can_create_program?(%{subscription_tier: :business_plus}, 100)
      true
  """
  @spec can_create_program?(tier_holder(), non_neg_integer()) :: boolean()
  def can_create_program?(%{subscription_tier: tier}, current_count) do
    tier
    |> get_provider_limit(:max_programs)
    |> within_limit?(current_count)
  end

  @doc """
  Returns the commission rate for a provider based on their tier.

  ## Examples

      iex> Entitlements.commission_rate(%{subscription_tier: :starter})
      0.18

      iex> Entitlements.commission_rate(%{subscription_tier: :professional})
      0.12

      iex> Entitlements.commission_rate(%{subscription_tier: :business_plus})
      0.08
  """
  @spec commission_rate(tier_holder()) :: float()
  def commission_rate(%{subscription_tier: tier}) do
    get_provider_limit(tier, :commission_rate)
  end

  @doc """
  Returns the list of allowed media types for a provider based on their tier.

  ## Examples

      iex> Entitlements.media_entitlements(%{subscription_tier: :starter})
      [:avatar]

      iex> Entitlements.media_entitlements(%{subscription_tier: :professional})
      [:avatar, :gallery, :video]

      iex> Entitlements.media_entitlements(%{subscription_tier: :business_plus})
      [:avatar, :gallery, :video, :promotional]
  """
  @spec media_entitlements(tier_holder()) :: [atom()]
  def media_entitlements(%{subscription_tier: tier}) do
    get_provider_limit(tier, :media)
  end

  @doc """
  Returns the maximum number of programs a provider can create based on their tier.

  Returns `:unlimited` for tiers with no limit.

  ## Examples

      iex> Entitlements.max_programs(%{subscription_tier: :starter})
      2

      iex> Entitlements.max_programs(%{subscription_tier: :professional})
      5

      iex> Entitlements.max_programs(%{subscription_tier: :business_plus})
      :unlimited
  """
  @spec max_programs(tier_holder()) :: non_neg_integer() | :unlimited
  def max_programs(%{subscription_tier: tier}) do
    get_provider_limit(tier, :max_programs)
  end

  @doc """
  Returns the number of team seats allowed for a provider based on their tier.

  ## Examples

      iex> Entitlements.team_seats_allowed(%{subscription_tier: :starter})
      1

      iex> Entitlements.team_seats_allowed(%{subscription_tier: :professional})
      1

      iex> Entitlements.team_seats_allowed(%{subscription_tier: :business_plus})
      3
  """
  @spec team_seats_allowed(tier_holder()) :: non_neg_integer()
  def team_seats_allowed(%{subscription_tier: tier}) do
    get_provider_limit(tier, :team_seats)
  end

  # Scope-based entitlement functions

  @doc """
  Checks if a scope can initiate messaging based on the associated profile's tier.

  Works with both parent and provider profiles. If both are present, returns true
  if either profile has messaging rights.

  ## Examples

      iex> Entitlements.can_initiate_messaging?(%{parent: %{subscription_tier: :explorer}})
      false

      iex> Entitlements.can_initiate_messaging?(%{parent: %{subscription_tier: :active}})
      true

      iex> Entitlements.can_initiate_messaging?(%{provider: %{subscription_tier: :professional}})
      true
  """
  @spec can_initiate_messaging?(map()) :: boolean()
  def can_initiate_messaging?(%{parent: parent, provider: provider}) do
    parent_can_message?(parent) or provider_can_message?(provider)
  end

  def can_initiate_messaging?(%{parent: parent}), do: parent_can_message?(parent)
  def can_initiate_messaging?(%{provider: provider}), do: provider_can_message?(provider)

  # Tier validation — delegates to Shared.SubscriptionTiers

  @doc """
  Returns the list of valid parent subscription tier atoms.

  ## Examples

      iex> Entitlements.parent_tiers()
      [:explorer, :active]
  """
  @spec parent_tiers() :: [atom()]
  defdelegate parent_tiers, to: SubscriptionTiers

  @doc """
  Returns the list of valid provider subscription tier atoms.

  ## Examples

      iex> Entitlements.provider_tiers()
      [:starter, :professional, :business_plus]
  """
  @spec provider_tiers() :: [atom()]
  defdelegate provider_tiers, to: SubscriptionTiers

  @doc """
  Checks if the given tier is a valid parent subscription tier.

  ## Examples

      iex> Entitlements.valid_parent_tier?(:explorer)
      true

      iex> Entitlements.valid_parent_tier?(:invalid)
      false
  """
  @spec valid_parent_tier?(term()) :: boolean()
  defdelegate valid_parent_tier?(tier), to: SubscriptionTiers

  @doc """
  Checks if the given tier is a valid provider subscription tier.

  ## Examples

      iex> Entitlements.valid_provider_tier?(:starter)
      true

      iex> Entitlements.valid_provider_tier?(:invalid)
      false
  """
  @spec valid_provider_tier?(term()) :: boolean()
  defdelegate valid_provider_tier?(tier), to: SubscriptionTiers

  @doc """
  Returns the default subscription tier for parents.

  ## Examples

      iex> Entitlements.default_parent_tier()
      :explorer
  """
  @spec default_parent_tier() :: atom()
  defdelegate default_parent_tier, to: SubscriptionTiers

  @doc """
  Returns the default subscription tier for providers.

  ## Examples

      iex> Entitlements.default_provider_tier()
      :starter
  """
  @spec default_provider_tier() :: atom()
  defdelegate default_provider_tier, to: SubscriptionTiers

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
