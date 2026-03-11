defmodule KlassHero.Enrollment.Domain.Events.EnrollmentIntegrationEventsTest do
  @moduledoc """
  Tests for EnrollmentIntegrationEvents factory module.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Domain.Events.EnrollmentIntegrationEvents
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  describe "invite_claimed/3" do
    test "creates an integration event with correct structure" do
      invite_id = Ecto.UUID.generate()
      payload = %{invite_id: invite_id, user_id: Ecto.UUID.generate()}

      event = EnrollmentIntegrationEvents.invite_claimed(invite_id, payload)

      assert %IntegrationEvent{} = event
      assert event.event_type == :invite_claimed
      assert event.source_context == :enrollment
      assert event.entity_type == :invite
      assert event.entity_id == invite_id
    end

    test "base_payload invite_id wins over caller-supplied invite_id" do
      real_id = Ecto.UUID.generate()
      conflicting_payload = %{invite_id: "should-be-overridden", extra: "data"}

      event = EnrollmentIntegrationEvents.invite_claimed(real_id, conflicting_payload)

      assert event.payload.invite_id == real_id
      assert event.payload.extra == "data"
    end

    test "raises for nil invite_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty invite_id string/,
                   fn -> EnrollmentIntegrationEvents.invite_claimed(nil) end
    end

    test "raises for empty string invite_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty invite_id string/,
                   fn -> EnrollmentIntegrationEvents.invite_claimed("") end
    end
  end

  describe "enrollment_cancelled/3" do
    test "creates integration event with correct structure" do
      enrollment_id = Ecto.UUID.generate()

      payload = %{
        enrollment_id: enrollment_id,
        program_id: Ecto.UUID.generate(),
        admin_id: Ecto.UUID.generate(),
        reason: "Admin cancellation"
      }

      event = EnrollmentIntegrationEvents.enrollment_cancelled(enrollment_id, payload)

      assert %IntegrationEvent{} = event
      assert event.event_type == :enrollment_cancelled
      assert event.source_context == :enrollment
      assert event.entity_type == :enrollment
      assert event.entity_id == enrollment_id
    end

    test "base_payload enrollment_id wins over caller-supplied enrollment_id" do
      real_id = Ecto.UUID.generate()
      conflicting_payload = %{enrollment_id: "should-be-overridden", extra: "data"}

      event = EnrollmentIntegrationEvents.enrollment_cancelled(real_id, conflicting_payload)

      assert event.payload.enrollment_id == real_id
      assert event.payload.extra == "data"
    end

    test "raises for nil enrollment_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty enrollment_id string/,
                   fn -> EnrollmentIntegrationEvents.enrollment_cancelled(nil) end
    end

    test "raises for empty string enrollment_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty enrollment_id string/,
                   fn -> EnrollmentIntegrationEvents.enrollment_cancelled("") end
    end
  end

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
