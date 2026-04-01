defmodule KlassHero.Provider.Domain.Events.ProviderEventsTest do
  use ExUnit.Case, async: true

  alias KlassHero.Provider.Domain.Events.ProviderEvents
  alias KlassHero.Provider.Domain.Models.ProviderProfile
  alias KlassHero.Shared.Domain.Events.DomainEvent

  describe "subscription_tier_changed/3" do
    test "creates a domain event with correct type and aggregate" do
      profile = %ProviderProfile{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Provider",
        subscription_tier: :professional
      }

      event = ProviderEvents.subscription_tier_changed(profile, :starter)

      assert %DomainEvent{} = event
      assert event.event_type == :subscription_tier_changed
      assert event.aggregate_id == profile.id
      assert event.aggregate_type == :provider
    end

    test "includes previous and new tier in payload" do
      profile = %ProviderProfile{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Provider",
        subscription_tier: :business_plus
      }

      event = ProviderEvents.subscription_tier_changed(profile, :professional)

      assert event.payload.provider_id == profile.id
      assert event.payload.previous_tier == :professional
      assert event.payload.new_tier == :business_plus
    end

    test "passes metadata options through" do
      profile = %ProviderProfile{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Provider",
        subscription_tier: :professional
      }

      correlation_id = Ecto.UUID.generate()

      event =
        ProviderEvents.subscription_tier_changed(profile, :starter, correlation_id: correlation_id)

      assert event.metadata.correlation_id == correlation_id
    end
  end
end
