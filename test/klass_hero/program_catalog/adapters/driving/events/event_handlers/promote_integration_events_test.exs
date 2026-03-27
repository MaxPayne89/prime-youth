defmodule KlassHero.ProgramCatalog.Adapters.Driving.Events.EventHandlers.PromoteIntegrationEventsTest do
  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.ProgramCatalog.Adapters.Driving.Events.EventHandlers.PromoteIntegrationEvents
  alias KlassHero.Shared.Adapters.Driven.Events.TestIntegrationEventPublisher
  alias KlassHero.Shared.Domain.Events.DomainEvent

  setup do
    setup_test_integration_events()
    :ok
  end

  describe "handle/1 — :program_created" do
    test "promotes to program_created integration event" do
      program_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:program_created, program_id, :program, %{
          provider_id: Ecto.UUID.generate(),
          title: "Summer Camp",
          category: "sports"
        })

      assert :ok = PromoteIntegrationEvents.handle(domain_event)

      event = assert_integration_event_published(:program_created)
      assert event.entity_id == program_id
      assert event.source_context == :program_catalog
      assert event.entity_type == :program
    end

    test "propagates publish failures as {:error, reason}" do
      program_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:program_created, program_id, :program, %{
          provider_id: Ecto.UUID.generate(),
          title: "Summer Camp",
          category: "sports"
        })

      TestIntegrationEventPublisher.configure_publish_error(:pubsub_down)

      assert {:error, :pubsub_down} = PromoteIntegrationEvents.handle(domain_event)
    end
  end

  describe "handle/1 — :program_updated" do
    test "promotes to program_updated integration event" do
      program_id = Ecto.UUID.generate()

      domain_event =
        DomainEvent.new(:program_updated, program_id, :program, %{
          provider_id: Ecto.UUID.generate(),
          title: "Updated Title",
          price: "200.00"
        })

      assert :ok = PromoteIntegrationEvents.handle(domain_event)

      event = assert_integration_event_published(:program_updated)
      assert event.entity_id == program_id
      assert event.source_context == :program_catalog
      assert event.payload.title == "Updated Title"
    end
  end
end
