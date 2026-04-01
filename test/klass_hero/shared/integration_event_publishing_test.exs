defmodule KlassHero.Shared.IntegrationEventPublishingTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias KlassHero.Shared.Adapters.Driven.Events.TestIntegrationEventPublisher
  alias KlassHero.Shared.Domain.Events.IntegrationEvent
  alias KlassHero.Shared.IntegrationEventPublishing

  setup do
    TestIntegrationEventPublisher.setup()
    :ok
  end

  describe "publish/1" do
    test "returns :ok and stores the event" do
      event = build_event(:some_event)

      assert :ok = IntegrationEventPublishing.publish(event)

      assert [published] = TestIntegrationEventPublisher.get_events()
      assert published.event_id == event.event_id
    end

    test "returns {:error, reason} on publisher failure" do
      TestIntegrationEventPublisher.configure_publish_error(:pubsub_down)
      event = build_event(:some_event)

      assert {:error, :pubsub_down} = IntegrationEventPublishing.publish(event)
    end
  end

  describe "publish_critical/3" do
    test "returns :ok on successful publish" do
      event = build_event(:critical_event)

      assert :ok = IntegrationEventPublishing.publish_critical(event, "critical_event")
    end

    test "returns {:error, reason} on publisher failure" do
      TestIntegrationEventPublisher.configure_publish_error(:pubsub_down)
      event = build_event(:critical_event)

      assert {:error, :pubsub_down} =
               IntegrationEventPublishing.publish_critical(event, "critical_event")
    end

    test "logs a warning when publish fails" do
      TestIntegrationEventPublisher.configure_publish_error(:connection_timeout)
      event = build_event(:critical_event)

      log =
        capture_log([level: :warning], fn ->
          IntegrationEventPublishing.publish_critical(event, "critical_event")
        end)

      assert log =~ "Failed to publish critical_event"
      assert log =~ "connection_timeout"
    end

    test "accepts optional log_fields and includes them in the log" do
      TestIntegrationEventPublisher.configure_publish_error(:net_error)
      event = build_event(:critical_event)

      log =
        capture_log([level: :warning], fn ->
          IntegrationEventPublishing.publish_critical(event, "critical_event", entity_id: "entity-123")
        end)

      assert log =~ "Failed to publish critical_event"
      assert log =~ "entity-123"
    end
  end

  describe "publish_best_effort/3" do
    test "returns :ok on successful publish" do
      event = build_event(:best_effort_event)

      assert :ok = IntegrationEventPublishing.publish_best_effort(event, "best_effort_event")
    end

    test "returns :ok even when publish fails (swallows the error)" do
      TestIntegrationEventPublisher.configure_publish_error(:pubsub_down)
      event = build_event(:best_effort_event)

      # Unlike publish_critical, best_effort never propagates errors
      assert :ok = IntegrationEventPublishing.publish_best_effort(event, "best_effort_event")
    end

    test "logs a warning when publish fails" do
      TestIntegrationEventPublisher.configure_publish_error(:network_error)
      event = build_event(:best_effort_event)

      log =
        capture_log([level: :warning], fn ->
          IntegrationEventPublishing.publish_best_effort(event, "best_effort_event")
        end)

      assert log =~ "Failed to publish best_effort_event"
      assert log =~ "network_error"
    end

    test "does not log on success" do
      event = build_event(:best_effort_event)

      log =
        capture_log(fn ->
          IntegrationEventPublishing.publish_best_effort(event, "best_effort_event")
        end)

      assert log == ""
    end
  end

  describe "publish_critical vs publish_best_effort error contract" do
    test "publish_critical propagates errors, publish_best_effort swallows them" do
      TestIntegrationEventPublisher.configure_publish_error(:publisher_down)
      event = build_event(:some_event)

      assert {:error, :publisher_down} =
               IntegrationEventPublishing.publish_critical(event, "some_event")

      # Clear publisher state (events + error) before next assertion
      TestIntegrationEventPublisher.setup()
      TestIntegrationEventPublisher.configure_publish_error(:publisher_down)

      assert :ok = IntegrationEventPublishing.publish_best_effort(event, "some_event")
    end
  end

  defp build_event(event_type) do
    IntegrationEvent.new(event_type, :test_context, :entity, Ecto.UUID.generate(), %{
      some_field: "value"
    })
  end
end
