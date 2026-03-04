defmodule KlassHero.Shared.SubscriptionTiersTest do
  use ExUnit.Case, async: true

  alias KlassHero.Shared.SubscriptionTiers

  describe "cast_provider_tier/1" do
    test "casts valid tier strings to atoms" do
      assert SubscriptionTiers.cast_provider_tier("starter") == {:ok, :starter}
      assert SubscriptionTiers.cast_provider_tier("professional") == {:ok, :professional}
      assert SubscriptionTiers.cast_provider_tier("business_plus") == {:ok, :business_plus}
    end

    test "returns tagged error for unknown tier string" do
      assert SubscriptionTiers.cast_provider_tier("invalid") == {:error, :invalid_tier}
      assert SubscriptionTiers.cast_provider_tier("") == {:error, :invalid_tier}
    end

    test "returns tagged error for non-binary input" do
      assert SubscriptionTiers.cast_provider_tier(nil) == {:error, :invalid_tier}
      assert SubscriptionTiers.cast_provider_tier(:starter) == {:error, :invalid_tier}
      assert SubscriptionTiers.cast_provider_tier(123) == {:error, :invalid_tier}
    end
  end
end
