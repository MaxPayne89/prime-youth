defmodule KlassHero.Provider.Application.UseCases.Providers.ChangeSubscriptionTierTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Provider.Application.UseCases.Providers.ChangeSubscriptionTier
  alias KlassHero.ProviderFixtures

  describe "execute/2" do
    test "changes subscription tier for an existing provider" do
      provider = ProviderFixtures.provider_profile_fixture(subscription_tier: "starter")
      assert {:ok, updated} = ChangeSubscriptionTier.execute(provider, :professional)
      assert updated.subscription_tier == :professional
    end

    test "returns error for same tier" do
      provider = ProviderFixtures.provider_profile_fixture(subscription_tier: "professional")
      assert {:error, :same_tier} = ChangeSubscriptionTier.execute(provider, :professional)
    end

    test "returns error for invalid tier" do
      provider = ProviderFixtures.provider_profile_fixture()
      assert {:error, :invalid_tier} = ChangeSubscriptionTier.execute(provider, :gold)
    end
  end
end
