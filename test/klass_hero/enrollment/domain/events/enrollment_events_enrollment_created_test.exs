defmodule KlassHero.Enrollment.Domain.Events.EnrollmentEventsEnrollmentCreatedTest do
  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent

  describe "enrollment_created/3" do
    test "creates event with correct type and aggregate" do
      enrollment_id = Ecto.UUID.generate()

      payload = %{
        enrollment_id: enrollment_id,
        child_id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate(),
        parent_user_id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        status: :pending
      }

      event = EnrollmentEvents.enrollment_created(enrollment_id, payload)

      assert %DomainEvent{} = event
      assert event.event_type == :enrollment_created
      assert event.aggregate_id == enrollment_id
      assert event.aggregate_type == :enrollment
      assert event.payload.enrollment_id == enrollment_id
      assert event.payload.child_id == payload.child_id
      assert event.payload.parent_user_id == payload.parent_user_id
      assert event.payload.program_id == payload.program_id
    end

    test "base_payload enrollment_id wins over caller-supplied enrollment_id" do
      real_id = Ecto.UUID.generate()
      conflicting_payload = %{enrollment_id: "should-be-overridden", extra: "data"}

      event = EnrollmentEvents.enrollment_created(real_id, conflicting_payload)

      assert event.payload.enrollment_id == real_id
      assert event.payload.extra == "data"
    end

    test "raises for nil enrollment_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty enrollment_id string/,
                   fn -> EnrollmentEvents.enrollment_created(nil) end
    end

    test "raises for empty string enrollment_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty enrollment_id string/,
                   fn -> EnrollmentEvents.enrollment_created("") end
    end
  end
end
