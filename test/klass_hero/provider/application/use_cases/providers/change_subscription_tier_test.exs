defmodule KlassHero.Provider.Application.UseCases.Providers.ChangeSubscriptionTierTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Provider.Application.UseCases.Providers.ChangeSubscriptionTier
  alias KlassHero.ProviderFixtures
  alias KlassHero.Shared.DomainEventBus

  describe "execute/2" do
    test "changes subscription tier for an existing provider" do
      provider = ProviderFixtures.provider_profile_fixture(subscription_tier: "starter")
      assert {:ok, updated} = ChangeSubscriptionTier.execute(provider, :professional)
      assert updated.subscription_tier == :professional
    end

    test "dispatches subscription_tier_changed event on success" do
      test_pid = self()

      DomainEventBus.subscribe(KlassHero.Provider, :subscription_tier_changed, fn event ->
        send(test_pid, {:domain_event, event})
        :ok
      end)

      provider = ProviderFixtures.provider_profile_fixture(subscription_tier: "starter")
      assert {:ok, _updated} = ChangeSubscriptionTier.execute(provider, :professional)

      assert_receive {:domain_event, event}
      assert event.event_type == :subscription_tier_changed
      assert event.aggregate_id == provider.id
      assert event.payload.provider_id == provider.id
      assert event.payload.previous_tier == :starter
      assert event.payload.new_tier == :professional
    end

    test "returns error for same tier without dispatching event" do
      provider = ProviderFixtures.provider_profile_fixture(subscription_tier: "professional")
      assert {:error, :same_tier} = ChangeSubscriptionTier.execute(provider, :professional)
    end

    test "returns error for invalid tier without dispatching event" do
      provider = ProviderFixtures.provider_profile_fixture()
      assert {:error, :invalid_tier} = ChangeSubscriptionTier.execute(provider, :gold)
    end
  end
end
