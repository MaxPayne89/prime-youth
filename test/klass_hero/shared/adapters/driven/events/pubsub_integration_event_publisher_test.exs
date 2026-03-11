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
  end
end
