defmodule KlassHero.Family.Domain.Events.FamilyEventsInviteFamilyReadyTest do
  @moduledoc """
  Tests for the invite_family_ready domain event factory in FamilyEvents.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Family.Domain.Events.FamilyEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent

  describe "invite_family_ready/3" do
    test "creates a domain event with correct structure" do
      invite_id = Ecto.UUID.generate()

      payload = %{
        invite_id: invite_id,
        user_id: Ecto.UUID.generate(),
        child_id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate()
      }

      event = FamilyEvents.invite_family_ready(invite_id, payload)

      assert %DomainEvent{} = event
      assert event.event_type == :invite_family_ready
      assert event.aggregate_id == invite_id
      assert event.aggregate_type == :invite
      assert event.payload.invite_id == invite_id
      assert event.payload.user_id == payload.user_id
      assert event.payload.child_id == payload.child_id
      assert event.payload.parent_id == payload.parent_id
      assert event.payload.program_id == payload.program_id
    end

    test "base_payload invite_id wins over caller-supplied invite_id" do
      real_id = Ecto.UUID.generate()
      conflicting_payload = %{invite_id: "should-be-overridden", extra: "data"}

      event = FamilyEvents.invite_family_ready(real_id, conflicting_payload)

      assert event.payload.invite_id == real_id
      assert event.payload.extra == "data"
    end

    test "raises for nil invite_id" do
      assert_raise ArgumentError, fn ->
        FamilyEvents.invite_family_ready(nil)
      end
    end

    test "raises for empty string invite_id" do
      assert_raise ArgumentError, fn ->
        FamilyEvents.invite_family_ready("")
      end
    end
  end
end
