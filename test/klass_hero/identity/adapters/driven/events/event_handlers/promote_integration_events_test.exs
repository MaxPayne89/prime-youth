defmodule KlassHero.Identity.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEventsTest do
  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Identity.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents
  alias KlassHero.Shared.Adapters.Driven.Events.TestIntegrationEventPublisher
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  setup do
    setup_test_integration_events()
    :ok
  end

  describe "handle/1 — :child_data_anonymized" do
    test "promotes to child_data_anonymized integration event" do
      child_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:child_data_anonymized, child_id, :child, %{child_id: child_id})

      assert :ok = PromoteIntegrationEvents.handle(domain_event)

      event = assert_integration_event_published(:child_data_anonymized)
      assert event.entity_id == child_id
      assert event.source_context == :identity
      assert IntegrationEvent.critical?(event)
    end

    test "propagates publish failures as {:error, reason}" do
      child_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:child_data_anonymized, child_id, :child, %{child_id: child_id})

      TestIntegrationEventPublisher.configure_publish_error(:pubsub_down)

      assert {:error, :pubsub_down} = PromoteIntegrationEvents.handle(domain_event)
    end
  end
end
