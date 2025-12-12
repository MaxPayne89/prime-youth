defmodule PrimeYouth.Accounts.EventPublisherTest do
  use PrimeYouth.DataCase, async: true

  import PrimeYouth.EventTestHelper

  alias PrimeYouth.Accounts.EventPublisher
  alias PrimeYouth.Shared.Domain.Events.DomainEvent

  setup do
    setup_test_events()
    :ok
  end

  describe "publish_user_registered/2" do
    test "publishes user_registered event with user data" do
      user = build_user(id: 1, email: "test@example.com", name: "Test User")

      assert :ok = EventPublisher.publish_user_registered(user)

      event = assert_event_published(:user_registered)
      assert event.aggregate_id == 1
      assert event.aggregate_type == :user
      assert event.payload.email == "test@example.com"
      assert event.payload.name == "Test User"
    end

    test "marks event as critical by default" do
      user = build_user()

      EventPublisher.publish_user_registered(user)

      event = assert_event_published(:user_registered)
      assert DomainEvent.critical?(event)
    end

    test "includes registration source in payload when provided" do
      user = build_user()

      EventPublisher.publish_user_registered(user, registration_source: :web)

      assert_event_published(:user_registered, %{registration_source: :web})
    end

    test "includes correlation_id in metadata when provided" do
      user = build_user()

      EventPublisher.publish_user_registered(user, correlation_id: "corr-123")

      event = assert_event_published(:user_registered)
      assert DomainEvent.correlation_id(event) == "corr-123"
    end
  end

  describe "publish_user_confirmed/2" do
    test "publishes user_confirmed event with user data" do
      confirmed_at = DateTime.utc_now()
      user = build_user(id: 2, email: "confirmed@example.com", confirmed_at: confirmed_at)

      assert :ok = EventPublisher.publish_user_confirmed(user)

      event = assert_event_published(:user_confirmed)
      assert event.aggregate_id == 2
      assert event.aggregate_type == :user
      assert event.payload.email == "confirmed@example.com"
      assert event.payload.confirmed_at == confirmed_at
    end

    test "is not marked as critical by default" do
      user = build_user(confirmed_at: DateTime.utc_now())

      EventPublisher.publish_user_confirmed(user)

      event = assert_event_published(:user_confirmed)
      refute DomainEvent.critical?(event)
    end

    test "includes confirmation_method in payload when provided" do
      user = build_user(confirmed_at: DateTime.utc_now())

      EventPublisher.publish_user_confirmed(user, confirmation_method: :email_link)

      assert_event_published(:user_confirmed, %{confirmation_method: :email_link})
    end
  end

  describe "publish_user_email_changed/2" do
    test "publishes user_email_changed event with email data" do
      user = build_user(id: 3, email: "new@example.com")

      assert :ok =
               EventPublisher.publish_user_email_changed(user, previous_email: "old@example.com")

      event = assert_event_published(:user_email_changed)
      assert event.aggregate_id == 3
      assert event.aggregate_type == :user
      assert event.payload.new_email == "new@example.com"
      assert event.payload.previous_email == "old@example.com"
    end

    test "is not marked as critical by default" do
      user = build_user()

      EventPublisher.publish_user_email_changed(user, previous_email: "old@example.com")

      event = assert_event_published(:user_email_changed)
      refute DomainEvent.critical?(event)
    end
  end

  describe "publish_user_anonymized/2" do
    test "publishes user_anonymized event with anonymized data" do
      user = build_user(id: 4, email: "deleted_4@anonymized.local")

      assert :ok =
               EventPublisher.publish_user_anonymized(user,
                 previous_email: "original@example.com"
               )

      event = assert_event_published(:user_anonymized)
      assert event.aggregate_id == 4
      assert event.aggregate_type == :user
      assert event.payload.anonymized_email == "deleted_4@anonymized.local"
      assert event.payload.previous_email == "original@example.com"
      assert event.payload.anonymized_at
    end

    test "marks event as critical by default" do
      user = build_user(email: "deleted_1@anonymized.local")

      EventPublisher.publish_user_anonymized(user, previous_email: "old@example.com")

      event = assert_event_published(:user_anonymized)
      assert DomainEvent.critical?(event)
    end

    test "includes correlation_id in metadata when provided" do
      user = build_user(email: "deleted_1@anonymized.local")

      EventPublisher.publish_user_anonymized(user,
        previous_email: "old@example.com",
        correlation_id: "gdpr-123"
      )

      event = assert_event_published(:user_anonymized)
      assert DomainEvent.correlation_id(event) == "gdpr-123"
    end
  end

  describe "event isolation" do
    test "events are isolated per test process" do
      user = build_user()
      EventPublisher.publish_user_registered(user)

      assert_event_count(1)
    end

    test "clear_events/0 clears all events" do
      user = build_user()
      EventPublisher.publish_user_registered(user)

      assert_event_count(1)

      clear_events()

      assert_no_events_published()
    end
  end

  defp build_user(attrs \\ []) do
    %PrimeYouth.Accounts.User{
      id: Keyword.get(attrs, :id, 1),
      email: Keyword.get(attrs, :email, "default@example.com"),
      name: Keyword.get(attrs, :name, "Default User"),
      confirmed_at: Keyword.get(attrs, :confirmed_at),
      hashed_password: "hashed",
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end
end
