defmodule KlassHero.Shared.Adapters.Driven.Events.EventHandlers.NotifyLiveViewsTest do
  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Shared.Adapters.Driven.Events.EventHandlers.NotifyLiveViews
  alias KlassHero.Shared.Domain.Events.DomainEvent

  setup do
    setup_test_events()
    :ok
  end

  describe "handle/1" do
    test "publishes event to derived topic" do
      event = DomainEvent.new(:some_event, Ecto.UUID.generate(), :some_aggregate, %{})

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:some_event)
    end
  end

  describe "derive_topic/1" do
    test "builds topic from aggregate_type and event_type" do
      event = DomainEvent.new(:event_happened, "id", :my_context, %{})
      assert NotifyLiveViews.derive_topic(event) == "my_context:event_happened"
    end
  end

  describe "build_topic/2" do
    test "builds topic string from atoms" do
      assert NotifyLiveViews.build_topic(:enrollment, :participant_policy_set) ==
               "enrollment:participant_policy_set"
    end
  end

  describe "safe_publish/2" do
    test "returns :ok on successful publish" do
      event = DomainEvent.new(:test_event, "id", :test, %{})
      assert :ok = NotifyLiveViews.safe_publish(event, "test:topic")
      assert_event_published(:test_event)
    end

    test "swallows publish failures and returns :ok" do
      event = DomainEvent.new(:failing_event, "id", :test, %{})
      assert :ok = NotifyLiveViews.safe_publish(event, "test:topic")
    end
  end
end
