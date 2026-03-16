defmodule KlassHero.Shared.Adapters.Driven.Events.PubSubIntegrationEventPublisherTest do
  use KlassHero.DataCase, async: true
  use Oban.Testing, repo: KlassHero.Repo

  alias KlassHero.Shared.Adapters.Driven.Events.PubSubIntegrationEventPublisher
  alias KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorker
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  describe "publish/1 with critical integration events" do
    test "enqueues Oban jobs for critical events with registered handlers" do
      event =
        IntegrationEvent.new(
          :invite_claimed,
          :enrollment,
          :invite,
          "invite-1",
          %{user_id: 1},
          criticality: :critical
        )

      # Trigger: using manual mode so Oban workers don't execute immediately
      # Why: inline mode runs the CriticalEventWorker synchronously, which would
      #      need DB sandbox access and pull in unrelated handler dependencies
      # Outcome: job is inserted and visible via assert_enqueued without executing
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = PubSubIntegrationEventPublisher.publish(event)

        assert_enqueued(
          worker: CriticalEventWorker,
          args: %{"event_type" => "invite_claimed", "event_kind" => "integration"}
        )
      end)
    end

    test "does not enqueue Oban jobs for normal events" do
      event =
        IntegrationEvent.new(
          :some_normal_event,
          :enrollment,
          :invite,
          "invite-1",
          %{}
        )

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = PubSubIntegrationEventPublisher.publish(event)

        # Normal events should just broadcast — no Oban jobs
        refute_enqueued(worker: CriticalEventWorker)
      end)
    end

    test "does not enqueue Oban jobs for critical events with no registered handlers" do
      # Event type with no entry in :critical_event_handlers config
      event =
        IntegrationEvent.new(
          :unknown_unregistered_event,
          :test_context,
          :test_entity,
          "entity-1",
          %{},
          criticality: :critical
        )

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = PubSubIntegrationEventPublisher.publish(event)

        refute_enqueued(worker: CriticalEventWorker)
      end)
    end
  end

  describe "publish/2 with explicit topic" do
    test "returns :ok when publishing to an explicit topic" do
      event =
        IntegrationEvent.new(
          :some_event,
          :test_context,
          :test_entity,
          "entity-1",
          %{}
        )

      topic = "integration:test_context:some_event"

      assert :ok = PubSubIntegrationEventPublisher.publish(event, topic)
    end

    test "delivers message to subscriber on the explicit topic" do
      event =
        IntegrationEvent.new(
          :some_event,
          :test_context,
          :test_entity,
          "entity-2",
          %{key: "value"}
        )

      topic = "integration:test_context:some_event_#{:erlang.unique_integer([:positive])}"

      Phoenix.PubSub.subscribe(KlassHero.PubSub, topic)
      assert :ok = PubSubIntegrationEventPublisher.publish(event, topic)

      assert_receive {:integration_event, received_event}
      assert received_event.event_type == :some_event
      assert received_event.entity_id == "entity-2"
    end
  end

  describe "publish_all/1" do
    test "returns :ok when all events publish successfully" do
      events = [
        IntegrationEvent.new(:event_a, :ctx_a, :entity, "e-1", %{}),
        IntegrationEvent.new(:event_b, :ctx_b, :entity, "e-2", %{})
      ]

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = PubSubIntegrationEventPublisher.publish_all(events)
        refute_enqueued(worker: CriticalEventWorker)
      end)
    end

    test "enqueues Oban jobs for each critical event in the list" do
      events = [
        IntegrationEvent.new(
          :invite_claimed,
          :enrollment,
          :invite,
          "invite-100",
          %{user_id: 99},
          criticality: :critical
        ),
        IntegrationEvent.new(:normal_event, :ctx, :entity, "e-3", %{})
      ]

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = PubSubIntegrationEventPublisher.publish_all(events)

        assert_enqueued(
          worker: CriticalEventWorker,
          args: %{"event_type" => "invite_claimed", "event_kind" => "integration"}
        )

        # Normal event in the same batch must not trigger a job
        refute_enqueued(
          worker: CriticalEventWorker,
          args: %{"event_type" => "normal_event"}
        )
      end)
    end
  end

  describe "build_topic/2" do
    test "formats topic as integration:{context}:{event_type}" do
      assert PubSubIntegrationEventPublisher.build_topic(:identity, :child_data_anonymized) ==
               "integration:identity:child_data_anonymized"
    end

    test "works with any atom context and event type" do
      assert PubSubIntegrationEventPublisher.build_topic(:enrollment, :invite_claimed) ==
               "integration:enrollment:invite_claimed"
    end
  end

  describe "derive_topic/1" do
    test "derives topic from an IntegrationEvent struct" do
      event =
        IntegrationEvent.new(:child_data_anonymized, :identity, :child, "child-uuid", %{})

      assert PubSubIntegrationEventPublisher.derive_topic(event) ==
               "integration:identity:child_data_anonymized"
    end
  end
end
