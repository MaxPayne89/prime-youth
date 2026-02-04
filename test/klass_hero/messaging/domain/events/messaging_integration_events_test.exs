defmodule KlassHero.Messaging.Domain.Events.MessagingIntegrationEventsTest do
  @moduledoc """
  Tests for MessagingIntegrationEvents factory module.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Messaging.Domain.Events.MessagingIntegrationEvents
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  describe "message_data_anonymized/3" do
    test "creates event with correct type, source_context, and entity_type" do
      user_id = Ecto.UUID.generate()

      event = MessagingIntegrationEvents.message_data_anonymized(user_id)

      assert event.event_type == :message_data_anonymized
      assert event.source_context == :messaging
      assert event.entity_type == :user
      assert event.entity_id == user_id
    end

    test "base_payload user_id wins over caller-supplied user_id" do
      real_id = Ecto.UUID.generate()
      conflicting_payload = %{user_id: "should-be-overridden", extra: "data"}

      event = MessagingIntegrationEvents.message_data_anonymized(real_id, conflicting_payload)

      assert event.payload.user_id == real_id
      assert event.payload.extra == "data"
    end

    test "marks event as critical by default" do
      user_id = Ecto.UUID.generate()

      event = MessagingIntegrationEvents.message_data_anonymized(user_id)

      assert IntegrationEvent.critical?(event)
    end

    test "allows overriding criticality via opts" do
      user_id = Ecto.UUID.generate()

      event =
        MessagingIntegrationEvents.message_data_anonymized(user_id, %{}, criticality: :normal)

      refute IntegrationEvent.critical?(event)
    end

    test "raises for nil user_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty user_id string/,
                   fn -> MessagingIntegrationEvents.message_data_anonymized(nil) end
    end

    test "raises for empty string user_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty user_id string/,
                   fn -> MessagingIntegrationEvents.message_data_anonymized("") end
    end
  end
end
