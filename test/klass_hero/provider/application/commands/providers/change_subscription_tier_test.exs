defmodule KlassHero.Provider.Application.Commands.Providers.ChangeSubscriptionTierTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Provider.Application.Commands.Providers.ChangeSubscriptionTier
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
      provider = ProviderFixtures.provider_profile_fixture(subscription_tier: "starter")
      provider_id = provider.id

      DomainEventBus.subscribe(KlassHero.Provider, :subscription_tier_changed, fn event ->
        send(test_pid, {:domain_event, event})
        :ok
      end)

      assert {:ok, _updated} = ChangeSubscriptionTier.execute(provider, :professional)

      # Pin aggregate_id: DomainEventBus is a singleton GenServer shared across
      # async tests, so other tests' tier-change events also land in this mailbox.
      assert_receive {:domain_event, %{aggregate_id: ^provider_id} = event}
      assert event.event_type == :subscription_tier_changed
      assert event.payload.provider_id == provider_id
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
