defmodule KlassHero.Provider.Domain.Models.ProviderProfileChangeTierTest do
  use ExUnit.Case, async: true

  alias KlassHero.Provider.Domain.Models.ProviderProfile

  defp build_profile(tier \\ :starter) do
    {:ok, profile} =
      ProviderProfile.new(%{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Business",
        subscription_tier: tier
      })

    profile
  end

  describe "change_tier/2" do
    test "upgrades to a valid tier" do
      profile = build_profile()
      assert {:ok, updated} = ProviderProfile.change_tier(profile, :professional)
      assert updated.subscription_tier == :professional
    end

    test "downgrades to a valid tier" do
      profile = build_profile(:business_plus)
      assert {:ok, updated} = ProviderProfile.change_tier(profile, :starter)
      assert updated.subscription_tier == :starter
    end

    test "rejects same tier" do
      profile = build_profile(:starter)
      assert {:error, :same_tier} = ProviderProfile.change_tier(profile, :starter)
    end

    test "rejects invalid tier" do
      profile = build_profile(:starter)
      assert {:error, :invalid_tier} = ProviderProfile.change_tier(profile, :gold)
    end
  end
end
