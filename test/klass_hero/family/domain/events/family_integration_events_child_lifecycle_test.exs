defmodule KlassHero.Family.Domain.Events.FamilyIntegrationEventsChildLifecycleTest do
  use ExUnit.Case, async: true

  alias KlassHero.Family.Domain.Events.FamilyIntegrationEvents
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  describe "child_created/3" do
    test "creates integration event with correct structure" do
      child_id = Ecto.UUID.generate()
      payload = %{child_id: child_id, parent_id: Ecto.UUID.generate(), first_name: "Emma", last_name: "Johnson"}
      event = FamilyIntegrationEvents.child_created(child_id, payload)
      assert %IntegrationEvent{} = event
      assert event.event_type == :child_created
      assert event.source_context == :family
      assert event.entity_type == :child
      assert event.entity_id == child_id
      assert event.payload.first_name == "Emma"
    end

    test "raises for empty string child_id" do
      assert_raise ArgumentError, ~r/requires a non-empty child_id string/, fn ->
        FamilyIntegrationEvents.child_created("")
      end
    end
  end

  describe "child_updated/3" do
    test "creates integration event with correct structure" do
      child_id = Ecto.UUID.generate()
      payload = %{child_id: child_id, parent_id: Ecto.UUID.generate(), first_name: "Emily", last_name: "Johnson"}
      event = FamilyIntegrationEvents.child_updated(child_id, payload)
      assert %IntegrationEvent{} = event
      assert event.event_type == :child_updated
      assert event.source_context == :family
      assert event.entity_type == :child
      assert event.entity_id == child_id
      assert event.payload.first_name == "Emily"
    end

    test "raises for empty string child_id" do
      assert_raise ArgumentError, ~r/requires a non-empty child_id string/, fn ->
        FamilyIntegrationEvents.child_updated("")
      end
    end
  end
end
