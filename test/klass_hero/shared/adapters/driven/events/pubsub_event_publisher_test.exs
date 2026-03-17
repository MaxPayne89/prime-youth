defmodule KlassHero.Shared.Adapters.Driven.Events.PubSubEventPublisherTest do
  use ExUnit.Case, async: true

  alias KlassHero.Shared.Adapters.Driven.Events.PubSubEventPublisher
  alias KlassHero.Shared.Domain.Events.DomainEvent

  describe "publish/1" do
    test "broadcasts domain event to the derived topic" do
      event = DomainEvent.new(:user_registered, "user-1", :user, %{email: "a@b.com"})
      topic = PubSubEventPublisher.derive_topic(event)

      Phoenix.PubSub.subscribe(KlassHero.PubSub, topic)

      assert :ok = PubSubEventPublisher.publish(event)

      assert_receive {:domain_event, received_event}
      assert received_event.event_type == :user_registered
      assert received_event.aggregate_id == "user-1"
    end
  end

  describe "publish/2" do
    test "broadcasts to an explicit topic with {:domain_event, event} tuple" do
      event = DomainEvent.new(:some_event, "agg-1", :test_agg, %{key: "value"})
      topic = "custom:topic_#{:erlang.unique_integer([:positive])}"

      Phoenix.PubSub.subscribe(KlassHero.PubSub, topic)

      assert :ok = PubSubEventPublisher.publish(event, topic)

      assert_receive {:domain_event, received_event}
      assert received_event.event_type == :some_event
      assert received_event.aggregate_id == "agg-1"
    end
  end

  describe "publish_all/1" do
    test "returns :ok when all events publish successfully" do
      events = [
        DomainEvent.new(:event_a, "agg-1", :type_a, %{}),
        DomainEvent.new(:event_b, "agg-2", :type_b, %{})
      ]

      assert :ok = PubSubEventPublisher.publish_all(events)
    end
  end

  describe "build_topic/2" do
    test "formats topic as {aggregate_type}:{event_type}" do
      assert PubSubEventPublisher.build_topic(:user, :registered) == "user:registered"
    end

    test "works with any atom types" do
      assert PubSubEventPublisher.build_topic(:enrollment, :confirmed) == "enrollment:confirmed"
    end
  end

  describe "derive_topic/1" do
    test "derives topic from a DomainEvent struct" do
      event = DomainEvent.new(:user_registered, 1, :user, %{})

      assert PubSubEventPublisher.derive_topic(event) == "user:user_registered"
    end
  end
end
