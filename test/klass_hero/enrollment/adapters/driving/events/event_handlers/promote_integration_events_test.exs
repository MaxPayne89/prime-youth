defmodule KlassHero.Enrollment.Adapters.Driving.Events.EventHandlers.PromoteIntegrationEventsTest do
  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Enrollment.Adapters.Driving.Events.EventHandlers.PromoteIntegrationEvents
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

  describe "handle/1 — :enrollment_cancelled" do
    test "promotes to enrollment_cancelled integration event" do
      enrollment_id = Ecto.UUID.generate()
      admin_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:enrollment_cancelled, enrollment_id, :enrollment, %{
          enrollment_id: enrollment_id,
          admin_id: admin_id,
          reason: "Duplicate booking"
        })

      assert :ok = PromoteIntegrationEvents.handle(domain_event)

      event = assert_integration_event_published(:enrollment_cancelled)
      assert event.entity_id == enrollment_id
      assert event.source_context == :enrollment
      assert event.entity_type == :enrollment
      assert event.payload.enrollment_id == enrollment_id
      assert event.payload.admin_id == admin_id
    end

    test "propagates publish failures as {:error, reason}" do
      enrollment_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:enrollment_cancelled, enrollment_id, :enrollment, %{
          enrollment_id: enrollment_id
        })

      TestIntegrationEventPublisher.configure_publish_error(:pubsub_down)

      assert {:error, :pubsub_down} = PromoteIntegrationEvents.handle(domain_event)
    end
  end

  describe "handle/1 — :invite_claimed" do
    test "promotes to invite_claimed integration event" do
      invite_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      program_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:invite_claimed, invite_id, :enrollment, %{
          invite_id: invite_id,
          user_id: user_id,
          program_id: program_id,
          is_new_user: true,
          child: %{first_name: "Emma", last_name: "Schmidt"},
          guardian: %{email: "parent@example.com"}
        })

      assert :ok = PromoteIntegrationEvents.handle(domain_event)

      event = assert_integration_event_published(:invite_claimed)
      assert event.entity_id == invite_id
      assert event.source_context == :enrollment
      assert event.entity_type == :invite
      assert event.payload.invite_id == invite_id
      assert event.payload.user_id == user_id
    end

    test "propagates publish failures as {:error, reason}" do
      invite_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:invite_claimed, invite_id, :enrollment, %{
          invite_id: invite_id
        })

      TestIntegrationEventPublisher.configure_publish_error(:pubsub_down)

      assert {:error, :pubsub_down} = PromoteIntegrationEvents.handle(domain_event)
    end
  end
end
