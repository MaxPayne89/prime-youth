defmodule KlassHero.Enrollment.Domain.Events.EnrollmentEventsTest do
  @moduledoc """
  Tests for EnrollmentEvents factory module.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent

  describe "participant_policy_set/3" do
    test "creates event with correct type and aggregate" do
      program_id = Ecto.UUID.generate()

      event = EnrollmentEvents.participant_policy_set(program_id)

      assert event.event_type == :participant_policy_set
      assert event.aggregate_id == program_id
      assert event.aggregate_type == :enrollment
    end

    test "base_payload program_id wins over caller-supplied program_id" do
      real_id = Ecto.UUID.generate()
      conflicting_payload = %{program_id: "should-be-overridden", extra: "data"}

      event = EnrollmentEvents.participant_policy_set(real_id, conflicting_payload)

      assert event.payload.program_id == real_id
      assert event.payload.extra == "data"
    end

    test "raises for nil program_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty program_id string/,
                   fn -> EnrollmentEvents.participant_policy_set(nil) end
    end

    test "raises for empty string program_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty program_id string/,
                   fn -> EnrollmentEvents.participant_policy_set("") end
    end
  end

  describe "bulk_invites_imported/3" do
    test "creates event with correct type and payload" do
      event = EnrollmentEvents.bulk_invites_imported("provider-1", ["prog-1", "prog-2"], 5)

      assert %DomainEvent{} = event
      assert event.event_type == :bulk_invites_imported
      assert event.aggregate_type == :enrollment
      assert event.aggregate_id == "provider-1"
      assert event.payload.provider_id == "provider-1"
      assert event.payload.program_ids == ["prog-1", "prog-2"]
      assert event.payload.count == 5
    end

    test "forwards opts to DomainEvent.new/5" do
      correlation_id = Ecto.UUID.generate()

      event =
        EnrollmentEvents.bulk_invites_imported("provider-1", ["prog-1"], 3,
          correlation_id: correlation_id
        )

      assert DomainEvent.correlation_id(event) == correlation_id
    end
  end
end
