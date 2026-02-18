defmodule KlassHero.Enrollment.Domain.Events.EnrollmentIntegrationEventsTest do
  @moduledoc """
  Tests for EnrollmentIntegrationEvents factory module.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Domain.Events.EnrollmentIntegrationEvents

  describe "participant_policy_set/3" do
    test "creates event with correct type, source_context, and entity_type" do
      program_id = Ecto.UUID.generate()

      event = EnrollmentIntegrationEvents.participant_policy_set(program_id)

      assert event.event_type == :participant_policy_set
      assert event.source_context == :enrollment
      assert event.entity_type == :participant_policy
      assert event.entity_id == program_id
    end

    test "base_payload program_id wins over caller-supplied program_id" do
      real_id = Ecto.UUID.generate()
      conflicting_payload = %{program_id: "should-be-overridden", extra: "data"}

      event = EnrollmentIntegrationEvents.participant_policy_set(real_id, conflicting_payload)

      assert event.payload.program_id == real_id
      assert event.payload.extra == "data"
    end

    test "raises for nil program_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty program_id string/,
                   fn -> EnrollmentIntegrationEvents.participant_policy_set(nil) end
    end

    test "raises for empty string program_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty program_id string/,
                   fn -> EnrollmentIntegrationEvents.participant_policy_set("") end
    end
  end
end
