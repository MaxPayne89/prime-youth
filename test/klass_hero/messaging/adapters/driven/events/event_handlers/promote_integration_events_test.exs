defmodule KlassHero.Messaging.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEventsTest do
  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Messaging.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents
  alias KlassHero.Shared.Adapters.Driven.Events.TestIntegrationEventPublisher
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  setup do
    setup_test_integration_events()
    :ok
  end

  describe "handle/1 — :user_data_anonymized" do
    test "promotes to message_data_anonymized integration event" do
      user_id = Ecto.UUID.generate()
      domain_event = DomainEvent.new(:user_data_anonymized, user_id, :user, %{user_id: user_id})

      assert :ok = PromoteIntegrationEvents.handle(domain_event)

      event = assert_integration_event_published(:message_data_anonymized)
      assert event.entity_id == user_id
      assert event.source_context == :messaging
      assert IntegrationEvent.critical?(event)
    end

    test "swallows publish failures with :ok" do
      user_id = Ecto.UUID.generate()
      domain_event = DomainEvent.new(:user_data_anonymized, user_id, :user, %{user_id: user_id})

      TestIntegrationEventPublisher.configure_publish_error(:pubsub_down)

      assert :ok = PromoteIntegrationEvents.handle(domain_event)
      assert_no_integration_events_published()
    end
  end
end
