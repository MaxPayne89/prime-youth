defmodule KlassHero.Shared.Adapters.Driven.Events.PubSubIntegrationEventPublisherTest do
  use KlassHero.DataCase, async: true
  use Oban.Testing, repo: KlassHero.Repo

  alias KlassHero.Shared.Adapters.Driven.Events.PubSubIntegrationEventPublisher
  alias KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorker
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  describe "publish/1 with critical integration events" do
    test "enqueues Oban jobs for critical events with registered handlers" do
      # Trigger: test-specific context/event so we don't broadcast on a real
      #          topic that supervision-tree EventSubscribers listen on
      # Why: real subscribers would receive the PubSub message and hit Ecto
      #      sandbox ownership errors under async: true
      # Outcome: isolated test that only exercises the Oban enqueueing path
      event =
        IntegrationEvent.new(
          :test_critical_event,
          :test_context,
          :test_entity,
          "entity-1",
          %{user_id: 1},
          criticality: :critical
        )

      topic = PubSubIntegrationEventPublisher.derive_topic(event)

      with_critical_handlers(%{topic => [{__MODULE__, :handle_event}]}, fn ->
        # Trigger: using manual mode so Oban workers don't execute immediately
        # Why: inline mode runs the CriticalEventWorker synchronously, which would
        #      need DB sandbox access and pull in unrelated handler dependencies
        # Outcome: job is inserted and visible via assert_enqueued without executing
        Oban.Testing.with_testing_mode(:manual, fn ->
          assert :ok = PubSubIntegrationEventPublisher.publish(event)

          assert_enqueued(
            worker: CriticalEventWorker,
            args: %{"event_type" => "test_critical_event", "event_kind" => "integration"}
          )
        end)
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

    test "enqueues one Oban job per registered handler for critical events" do
      event =
        IntegrationEvent.new(
          :test_multi_handler_event,
          :test_context,
          :test_entity,
          "entity-multi",
          %{user_id: "u-1"},
          criticality: :critical
        )

      topic = PubSubIntegrationEventPublisher.derive_topic(event)

      handlers = [
        {__MODULE__, :handle_event},
        {__MODULE__, :handle_event_alt},
        {__MODULE__, :handle_event_third}
      ]

      with_critical_handlers(%{topic => handlers}, fn ->
        Oban.Testing.with_testing_mode(:manual, fn ->
          assert :ok = PubSubIntegrationEventPublisher.publish(event)

          enqueued = all_enqueued(worker: CriticalEventWorker)
          assert length(enqueued) == 3

          handler_refs = Enum.map(enqueued, & &1.args["handler"])
          assert length(Enum.uniq(handler_refs)) == 3
        end)
      end)
    end

    test "does not enqueue Oban jobs for critical events with no registered handlers" do
      event =
        IntegrationEvent.new(
          :unregistered_event,
          :test_context,
          :test_entity,
          "entity-1",
          %{},
          criticality: :critical
        )

      # Trigger: explicitly empty handler registry
      # Why: relying on the global config implicitly missing an entry is fragile —
      #      a future config addition could silently break this test
      # Outcome: guarantees "no handlers" precondition regardless of app config
      with_critical_handlers(%{}, fn ->
        Oban.Testing.with_testing_mode(:manual, fn ->
          assert :ok = PubSubIntegrationEventPublisher.publish(event)

          refute_enqueued(worker: CriticalEventWorker)
        end)
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
      critical_event =
        IntegrationEvent.new(
          :test_batch_critical,
          :test_context,
          :test_entity,
          "entity-100",
          %{user_id: 99},
          criticality: :critical
        )

      normal_event = IntegrationEvent.new(:normal_event, :test_context, :entity, "e-3", %{})

      topic = PubSubIntegrationEventPublisher.derive_topic(critical_event)

      with_critical_handlers(%{topic => [{__MODULE__, :handle_event}]}, fn ->
        Oban.Testing.with_testing_mode(:manual, fn ->
          assert :ok = PubSubIntegrationEventPublisher.publish_all([critical_event, normal_event])

          assert_enqueued(
            worker: CriticalEventWorker,
            args: %{"event_type" => "test_batch_critical", "event_kind" => "integration"}
          )

          # Normal event in the same batch must not trigger a job
          refute_enqueued(
            worker: CriticalEventWorker,
            args: %{"event_type" => "normal_event"}
          )
        end)
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

  # Temporarily overrides :critical_event_handlers config for the duration of `fun`,
  # restoring the original value on exit regardless of success or failure.
  defp with_critical_handlers(handlers, fun) do
    original = Application.get_env(:klass_hero, :critical_event_handlers, %{})
    Application.put_env(:klass_hero, :critical_event_handlers, handlers)

    try do
      fun.()
    after
      Application.put_env(:klass_hero, :critical_event_handlers, original)
    end
  end
end
