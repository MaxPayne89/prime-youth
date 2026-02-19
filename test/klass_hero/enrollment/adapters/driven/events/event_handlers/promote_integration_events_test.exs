defmodule KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEventsTest do
  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents
  alias KlassHero.Shared.Adapters.Driven.Events.TestIntegrationEventPublisher
  alias KlassHero.Shared.Domain.Events.DomainEvent

  setup do
    setup_test_integration_events()
    :ok
  end

  describe "handle/1 — :participant_policy_set" do
    test "promotes to participant_policy_set integration event" do
      program_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:participant_policy_set, program_id, :enrollment, %{
          program_id: program_id
        })

      assert :ok = PromoteIntegrationEvents.handle(domain_event)

      event = assert_integration_event_published(:participant_policy_set)
      assert event.entity_id == program_id
      assert event.source_context == :enrollment
      assert event.entity_type == :participant_policy
    end

    test "propagates publish failures as {:error, reason}" do
      program_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:participant_policy_set, program_id, :enrollment, %{
          program_id: program_id
        })

      TestIntegrationEventPublisher.configure_publish_error(:pubsub_down)

      assert {:error, :pubsub_down} = PromoteIntegrationEvents.handle(domain_event)
    end
  end
end
