defmodule PrimeYouth.Family.Adapters.Driven.Events.UserEventHandlerTest do
  @moduledoc """
  Unit tests for UserEventHandler.

  Tests pattern matching correctness and event handling behavior.
  """

  use ExUnit.Case, async: true

  alias PrimeYouth.Family.Adapters.Driven.Events.UserEventHandler
  alias PrimeYouth.Shared.Domain.Events.DomainEvent

  describe "subscribed_events/0" do
    test "returns list of subscribed event types" do
      subscribed = UserEventHandler.subscribed_events()

      assert is_list(subscribed)
      assert :user_registered in subscribed
      assert :user_confirmed in subscribed
    end

    test "returns exactly two event types" do
      subscribed = UserEventHandler.subscribed_events()

      assert length(subscribed) == 2
    end

    test "returns unique event types" do
      subscribed = UserEventHandler.subscribed_events()

      assert Enum.uniq(subscribed) == subscribed
    end
  end

  describe "handle_event/1 with :user_registered event" do
    test "returns :ok for user_registered event" do
      event = DomainEvent.new(:user_registered, 123, :user, %{email: "test@example.com"})

      assert :ok = UserEventHandler.handle_event(event)
    end

    test "handles user_registered with integer aggregate_id" do
      event =
        DomainEvent.new(:user_registered, 456, :user, %{
          email: "user@example.com",
          name: "Test User"
        })

      assert :ok = UserEventHandler.handle_event(event)
    end

    test "handles user_registered with string aggregate_id" do
      user_id = Ecto.UUID.generate()
      event = DomainEvent.new(:user_registered, user_id, :user, %{email: "string-id@example.com"})

      assert :ok = UserEventHandler.handle_event(event)
    end

    test "handles user_registered with empty payload" do
      event = DomainEvent.new(:user_registered, 789, :user, %{})

      assert :ok = UserEventHandler.handle_event(event)
    end

    test "handles user_registered with rich payload" do
      event =
        DomainEvent.new(:user_registered, 101, :user, %{
          email: "rich@example.com",
          name: "Rich User",
          confirmed_at: nil,
          metadata: %{
            source: "web",
            ip_address: "192.168.1.1"
          }
        })

      assert :ok = UserEventHandler.handle_event(event)
    end
  end

  describe "handle_event/1 with :user_confirmed event" do
    test "returns :ok for user_confirmed event" do
      event = DomainEvent.new(:user_confirmed, 234, :user, %{email: "confirmed@example.com"})

      assert :ok = UserEventHandler.handle_event(event)
    end

    test "handles user_confirmed with integer aggregate_id" do
      event =
        DomainEvent.new(:user_confirmed, 567, :user, %{
          email: "user@example.com",
          confirmed_at: ~U[2024-01-15 10:30:00Z]
        })

      assert :ok = UserEventHandler.handle_event(event)
    end

    test "handles user_confirmed with string aggregate_id" do
      user_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:user_confirmed, user_id, :user, %{
          email: "string-confirmed@example.com"
        })

      assert :ok = UserEventHandler.handle_event(event)
    end

    test "handles user_confirmed with empty payload" do
      event = DomainEvent.new(:user_confirmed, 890, :user, %{})

      assert :ok = UserEventHandler.handle_event(event)
    end

    test "handles user_confirmed with metadata" do
      event =
        DomainEvent.new(:user_confirmed, 111, :user, %{
          email: "metadata@example.com",
          confirmed_at: ~U[2024-01-15 14:00:00Z]
        })

      assert :ok = UserEventHandler.handle_event(event)
    end
  end

  describe "handle_event/1 with unsubscribed events" do
    test "returns :ignore for user_deleted event" do
      event = DomainEvent.new(:user_deleted, 345, :user, %{})

      assert :ignore = UserEventHandler.handle_event(event)
    end

    test "returns :ignore for user_updated event" do
      event = DomainEvent.new(:user_updated, 678, :user, %{email: "updated@example.com"})

      assert :ignore = UserEventHandler.handle_event(event)
    end

    test "returns :ignore for password_changed event" do
      event = DomainEvent.new(:password_changed, 901, :user, %{})

      assert :ignore = UserEventHandler.handle_event(event)
    end

    test "returns :ignore for email_changed event" do
      event =
        DomainEvent.new(:email_changed, 112, :user, %{
          old_email: "old@example.com",
          new_email: "new@example.com"
        })

      assert :ignore = UserEventHandler.handle_event(event)
    end

    test "returns :ignore for events from different aggregate types" do
      # Order event
      order_event = DomainEvent.new(:order_placed, 123, :order, %{total: 100})
      assert :ignore = UserEventHandler.handle_event(order_event)

      # Program event
      program_event = DomainEvent.new(:program_created, 456, :program, %{title: "Test"})
      assert :ignore = UserEventHandler.handle_event(program_event)

      # Enrollment event
      enrollment_event = DomainEvent.new(:enrollment_confirmed, 789, :enrollment, %{})
      assert :ignore = UserEventHandler.handle_event(enrollment_event)
    end

    test "returns :ignore for unknown event types" do
      event = DomainEvent.new(:unknown_event, 999, :unknown, %{})

      assert :ignore = UserEventHandler.handle_event(event)
    end
  end

  describe "event structure preservation" do
    test "does not modify event aggregate_id" do
      event = DomainEvent.new(:user_registered, 555, :user, %{email: "test@example.com"})

      UserEventHandler.handle_event(event)

      assert event.aggregate_id == 555
    end

    test "does not modify event payload" do
      original_payload = %{
        email: "preserve@example.com",
        name: "Preserve Test",
        metadata: %{source: "test"}
      }

      event = DomainEvent.new(:user_registered, 666, :user, original_payload)

      UserEventHandler.handle_event(event)

      assert event.payload == original_payload
      assert event.payload.email == "preserve@example.com"
      assert event.payload.name == "Preserve Test"
      assert event.payload.metadata.source == "test"
    end

    test "does not modify event_type" do
      event = DomainEvent.new(:user_confirmed, 777, :user, %{})

      UserEventHandler.handle_event(event)

      assert event.event_type == :user_confirmed
    end

    test "does not modify aggregate_type" do
      event = DomainEvent.new(:user_registered, 888, :user, %{})

      UserEventHandler.handle_event(event)

      assert event.aggregate_type == :user
    end

    test "preserves event_id" do
      event = DomainEvent.new(:user_registered, 999, :user, %{})
      original_event_id = event.event_id

      UserEventHandler.handle_event(event)

      assert event.event_id == original_event_id
    end

    test "preserves occurred_at timestamp" do
      event = DomainEvent.new(:user_registered, 1000, :user, %{})
      original_timestamp = event.occurred_at

      UserEventHandler.handle_event(event)

      assert event.occurred_at == original_timestamp
    end
  end
end
