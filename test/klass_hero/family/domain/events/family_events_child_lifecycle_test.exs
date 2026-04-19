defmodule KlassHero.Family.Domain.Events.FamilyEventsChildLifecycleTest do
  use ExUnit.Case, async: true

  alias KlassHero.Family.Domain.Events.FamilyEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent

  describe "child_created/3" do
    test "creates event with correct type and aggregate" do
      child_id = Ecto.UUID.generate()
      payload = %{child_id: child_id, parent_id: Ecto.UUID.generate(), first_name: "Emma", last_name: "Johnson"}

      event = FamilyEvents.child_created(child_id, payload)

      assert %DomainEvent{} = event
      assert event.event_type == :child_created
      assert event.aggregate_id == child_id
      assert event.aggregate_type == :child
      assert event.payload.child_id == child_id
      assert event.payload.first_name == "Emma"
    end

    test "base_payload child_id wins over caller-supplied child_id" do
      real_id = Ecto.UUID.generate()
      payload = %{child_id: "should-be-overridden", first_name: "Emma"}
      event = FamilyEvents.child_created(real_id, payload)
      assert event.payload.child_id == real_id
      assert event.payload.first_name == "Emma"
    end

    test "raises for nil child_id" do
      assert_raise ArgumentError, ~r/requires a non-empty child_id string/, fn ->
        FamilyEvents.child_created(nil)
      end
    end

    test "raises for empty string child_id" do
      assert_raise ArgumentError, ~r/requires a non-empty child_id string/, fn ->
        FamilyEvents.child_created("")
      end
    end
  end

  describe "child_updated/3" do
    test "creates event with correct type and aggregate" do
      child_id = Ecto.UUID.generate()
      payload = %{child_id: child_id, parent_id: Ecto.UUID.generate(), first_name: "Emily", last_name: "Johnson"}
      event = FamilyEvents.child_updated(child_id, payload)
      assert %DomainEvent{} = event
      assert event.event_type == :child_updated
      assert event.aggregate_id == child_id
      assert event.aggregate_type == :child
      assert event.payload.first_name == "Emily"
    end

    test "raises for empty string child_id" do
      assert_raise ArgumentError, ~r/requires a non-empty child_id string/, fn ->
        FamilyEvents.child_updated("")
      end
    end
  end
end
