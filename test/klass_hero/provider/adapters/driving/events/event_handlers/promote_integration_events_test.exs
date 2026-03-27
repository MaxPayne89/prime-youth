defmodule KlassHero.Provider.Adapters.Driving.Events.EventHandlers.PromoteIntegrationEventsTest do
  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Provider.Adapters.Driving.Events.EventHandlers.PromoteIntegrationEvents
  alias KlassHero.Shared.Adapters.Driven.Events.TestIntegrationEventPublisher
  alias KlassHero.Shared.Domain.Events.DomainEvent

  setup do
    setup_test_integration_events()
    :ok
  end

  describe "handle/1 — :subscription_tier_changed" do
    test "promotes to subscription_tier_changed integration event" do
      provider_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:subscription_tier_changed, provider_id, :provider, %{
          provider_id: provider_id,
          previous_tier: :starter,
          new_tier: :professional
        })

      assert :ok = PromoteIntegrationEvents.handle(domain_event)

      event = assert_integration_event_published(:subscription_tier_changed)
      assert event.entity_id == provider_id
      assert event.source_context == :provider
      assert event.entity_type == :provider_profile
      assert event.payload.provider_id == provider_id
      assert event.payload.previous_tier == :starter
      assert event.payload.new_tier == :professional
    end

    test "propagates publish failures as {:error, reason}" do
      provider_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:subscription_tier_changed, provider_id, :provider, %{
          provider_id: provider_id,
          previous_tier: :starter,
          new_tier: :professional
        })

      TestIntegrationEventPublisher.configure_publish_error(:pubsub_down)

      assert {:error, :pubsub_down} = PromoteIntegrationEvents.handle(domain_event)
    end
  end
end
