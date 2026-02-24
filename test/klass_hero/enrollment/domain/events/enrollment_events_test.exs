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

    test "raises for nil provider_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty provider_id string/,
                   fn -> EnrollmentEvents.bulk_invites_imported(nil, ["prog-1"], 1) end
    end

    test "raises for empty string provider_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty provider_id string/,
                   fn -> EnrollmentEvents.bulk_invites_imported("", ["prog-1"], 1) end
    end

    test "raises for non-list program_ids" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty provider_id string/,
                   fn -> EnrollmentEvents.bulk_invites_imported("provider-1", "not-a-list", 1) end
    end

    test "raises for non-integer count" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty provider_id string/,
                   fn -> EnrollmentEvents.bulk_invites_imported("provider-1", ["prog-1"], "5") end
    end
  end

  describe "invite_resend_requested/4" do
    test "creates event with correct type and payload" do
      provider_id = Ecto.UUID.generate()
      invite_id = Ecto.UUID.generate()
      program_id = Ecto.UUID.generate()

      event = EnrollmentEvents.invite_resend_requested(provider_id, invite_id, program_id)

      assert %DomainEvent{} = event
      assert event.event_type == :invite_resend_requested
      assert event.aggregate_type == :enrollment
      assert event.aggregate_id == invite_id
      assert event.payload.provider_id == provider_id
      assert event.payload.invite_id == invite_id
      assert event.payload.program_id == program_id
    end

    test "forwards opts to DomainEvent.new/5" do
      correlation_id = Ecto.UUID.generate()

      event =
        EnrollmentEvents.invite_resend_requested(
          Ecto.UUID.generate(),
          Ecto.UUID.generate(),
          Ecto.UUID.generate(),
          correlation_id: correlation_id
        )

      assert DomainEvent.correlation_id(event) == correlation_id
    end

    test "raises for empty provider_id" do
      assert_raise ArgumentError,
                   ~r/invite_resend_requested/,
                   fn ->
                     EnrollmentEvents.invite_resend_requested(
                       "",
                       Ecto.UUID.generate(),
                       Ecto.UUID.generate()
                     )
                   end
    end

    test "raises for empty invite_id" do
      assert_raise ArgumentError,
                   ~r/invite_resend_requested/,
                   fn ->
                     EnrollmentEvents.invite_resend_requested(
                       Ecto.UUID.generate(),
                       "",
                       Ecto.UUID.generate()
                     )
                   end
    end

    test "raises for empty program_id" do
      assert_raise ArgumentError,
                   ~r/invite_resend_requested/,
                   fn ->
                     EnrollmentEvents.invite_resend_requested(
                       Ecto.UUID.generate(),
                       Ecto.UUID.generate(),
                       ""
                     )
                   end
    end
  end
end
