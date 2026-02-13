defmodule KlassHero.Family.Domain.Events.FamilyEventsTest do
  @moduledoc """
  Tests for FamilyEvents factory module.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Family.Domain.Events.FamilyEvents

  describe "child_data_anonymized/3" do
    test "base_payload child_id wins over caller-supplied child_id" do
      real_id = Ecto.UUID.generate()
      conflicting_payload = %{child_id: "should-be-overridden", extra: "data"}

      event = FamilyEvents.child_data_anonymized(real_id, conflicting_payload)

      assert event.payload.child_id == real_id
      assert event.payload.extra == "data"
    end

    test "creates event with correct type and criticality" do
      child_id = Ecto.UUID.generate()

      event = FamilyEvents.child_data_anonymized(child_id)

      assert event.event_type == :child_data_anonymized
      assert event.aggregate_id == child_id
    end

    test "raises for nil child_id" do
      assert_raise ArgumentError, fn ->
        FamilyEvents.child_data_anonymized(nil)
      end
    end

    test "raises for empty string child_id" do
      assert_raise ArgumentError, fn ->
        FamilyEvents.child_data_anonymized("")
      end
    end
  end
end
