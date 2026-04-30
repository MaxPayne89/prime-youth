defmodule KlassHero.Enrollment.Domain.Events.EnrollmentEventsInviteDeletedTest do
  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent

  describe "invite_deleted/3" do
    test "creates a domain event with correct structure" do
      invite_id = Ecto.UUID.generate()
      program_id = Ecto.UUID.generate()
      provider_id = Ecto.UUID.generate()

      payload = %{
        invite_id: invite_id,
        program_id: program_id,
        provider_id: provider_id
      }

      event = EnrollmentEvents.invite_deleted(invite_id, payload)

      assert %DomainEvent{} = event
      assert event.event_type == :invite_deleted
      assert event.aggregate_id == invite_id
      assert event.aggregate_type == :invite
      assert event.payload.invite_id == invite_id
      assert event.payload.program_id == program_id
      assert event.payload.provider_id == provider_id
    end

    test "raises on empty invite_id" do
      assert_raise ArgumentError, fn ->
        EnrollmentEvents.invite_deleted("", %{})
      end
    end
  end
end
