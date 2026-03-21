defmodule KlassHero.Provider.Domain.Events.ProviderIntegrationEventsStaffTest do
  @moduledoc """
  Tests for staff-related factory functions in ProviderIntegrationEvents.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Provider.Domain.Events.ProviderIntegrationEvents
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  describe "staff_member_invited/3" do
    setup do
      %{
        staff_member_id: Ecto.UUID.generate(),
        provider_id: Ecto.UUID.generate()
      }
    end

    test "creates event with correct type, source_context, and entity_type", %{
      staff_member_id: staff_member_id
    } do
      event = ProviderIntegrationEvents.staff_member_invited(staff_member_id)

      assert %IntegrationEvent{} = event
      assert event.event_type == :staff_member_invited
      assert event.source_context == :provider
      assert event.entity_type == :staff_member
      assert event.entity_id == staff_member_id
    end

    test "includes staff_member_id in payload", %{
      staff_member_id: staff_member_id,
      provider_id: provider_id
    } do
      event =
        ProviderIntegrationEvents.staff_member_invited(staff_member_id, %{
          provider_id: provider_id,
          email: "staff@example.com"
        })

      assert event.payload.staff_member_id == staff_member_id
      assert event.payload.provider_id == provider_id
      assert event.payload.email == "staff@example.com"
    end

    test "base_payload staff_member_id wins over caller-supplied staff_member_id", %{
      staff_member_id: real_id
    } do
      conflicting_payload = %{staff_member_id: "should-be-overridden", extra: "data"}

      event = ProviderIntegrationEvents.staff_member_invited(real_id, conflicting_payload)

      assert event.payload.staff_member_id == real_id
      assert event.payload.extra == "data"
    end

    test "marks event as critical by default", %{staff_member_id: staff_member_id} do
      event = ProviderIntegrationEvents.staff_member_invited(staff_member_id)

      assert IntegrationEvent.critical?(event)
    end

    test "allows overriding criticality via opts", %{staff_member_id: staff_member_id} do
      event =
        ProviderIntegrationEvents.staff_member_invited(staff_member_id, %{}, criticality: :normal)

      refute IntegrationEvent.critical?(event)
    end

    test "raises for nil staff_member_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty staff_member_id string/,
                   fn -> ProviderIntegrationEvents.staff_member_invited(nil) end
    end

    test "raises for empty string staff_member_id" do
      assert_raise ArgumentError,
                   ~r/requires a non-empty staff_member_id string/,
                   fn -> ProviderIntegrationEvents.staff_member_invited("") end
    end
  end
end
