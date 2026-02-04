defmodule KlassHero.Messaging.IntegrationEventPublisherTest do
  @moduledoc """
  Tests for the Messaging IntegrationEventPublisher convenience module.
  """

  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Messaging.IntegrationEventPublisher
  alias KlassHero.Shared.Adapters.Driven.Events.TestIntegrationEventPublisher
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  describe "publish_message_data_anonymized/2" do
    setup do
      setup_test_integration_events()
      :ok
    end

    test "publishes event with correct type, source, and entity_id" do
      user_id = Ecto.UUID.generate()

      assert :ok = IntegrationEventPublisher.publish_message_data_anonymized(user_id)

      event = assert_integration_event_published(:message_data_anonymized)
      assert event.entity_id == user_id
      assert event.source_context == :messaging
      assert event.entity_type == :user
      assert event.payload.user_id == user_id
      assert IntegrationEvent.critical?(event)
    end

    test "forwards opts to event factory" do
      user_id = Ecto.UUID.generate()
      correlation_id = Ecto.UUID.generate()

      assert :ok =
               IntegrationEventPublisher.publish_message_data_anonymized(
                 user_id,
                 correlation_id: correlation_id
               )

      event = assert_integration_event_published(:message_data_anonymized)
      assert event.metadata.correlation_id == correlation_id
    end

    test "raises FunctionClauseError for non-string input" do
      assert_raise FunctionClauseError, fn ->
        IntegrationEventPublisher.publish_message_data_anonymized(nil)
      end

      assert_raise FunctionClauseError, fn ->
        IntegrationEventPublisher.publish_message_data_anonymized(123)
      end
    end

    test "propagates publish infrastructure errors" do
      user_id = Ecto.UUID.generate()

      TestIntegrationEventPublisher.configure_publish_error(:pubsub_down)

      assert {:error, :pubsub_down} =
               IntegrationEventPublisher.publish_message_data_anonymized(user_id)
    end
  end
end
