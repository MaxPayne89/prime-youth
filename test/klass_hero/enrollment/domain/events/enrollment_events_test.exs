defmodule KlassHero.Enrollment.Domain.Events.EnrollmentEventsTest do
  @moduledoc """
  Tests for EnrollmentEvents factory module.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents

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
end
