defmodule KlassHero.Provider.Domain.Events.ProviderEventsTest do
  use ExUnit.Case, async: true

  alias KlassHero.Provider.Domain.Events.ProviderEvents
  alias KlassHero.Provider.Domain.Models.IncidentReport
  alias KlassHero.Provider.Domain.Models.ProviderProfile
  alias KlassHero.Shared.Domain.Events.DomainEvent

  describe "subscription_tier_changed/3" do
    test "creates a domain event with correct type and aggregate" do
      profile = %ProviderProfile{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Provider",
        subscription_tier: :professional
      }

      event = ProviderEvents.subscription_tier_changed(profile, :starter)

      assert %DomainEvent{} = event
      assert event.event_type == :subscription_tier_changed
      assert event.aggregate_id == profile.id
      assert event.aggregate_type == :provider
    end

    test "includes previous and new tier in payload" do
      profile = %ProviderProfile{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Provider",
        subscription_tier: :business_plus
      }

      event = ProviderEvents.subscription_tier_changed(profile, :professional)

      assert event.payload.provider_id == profile.id
      assert event.payload.previous_tier == :professional
      assert event.payload.new_tier == :business_plus
    end

    test "passes metadata options through" do
      profile = %ProviderProfile{
        id: Ecto.UUID.generate(),
        identity_id: Ecto.UUID.generate(),
        business_name: "Test Provider",
        subscription_tier: :professional
      }

      correlation_id = Ecto.UUID.generate()

      event =
        ProviderEvents.subscription_tier_changed(profile, :starter, correlation_id: correlation_id)

      assert event.metadata.correlation_id == correlation_id
    end
  end

  describe "incident_reported/2" do
    test "returns a DomainEvent with the documented payload shape" do
      report = %IncidentReport{
        id: "r1",
        provider_profile_id: "prov-1",
        reporter_user_id: "user-uuid",
        program_id: "prog-1",
        session_id: nil,
        category: :injury,
        severity: :high,
        description: "Scraped knee while running",
        occurred_at: ~U[2026-04-20 10:00:00Z],
        photo_url: "reports/prov-1/photo.jpg",
        original_filename: "photo.jpg"
      }

      event = ProviderEvents.incident_reported(report)

      assert %DomainEvent{
               event_type: :incident_reported,
               aggregate_id: "r1",
               aggregate_type: :provider,
               payload: payload
             } = event

      assert payload == %{
               incident_report_id: "r1",
               provider_id: "prov-1",
               program_id: "prog-1",
               session_id: nil,
               reporter_user_id: "user-uuid",
               category: :injury,
               severity: :high,
               occurred_at: ~U[2026-04-20 10:00:00Z],
               has_photo: true
             }

      refute Map.has_key?(payload, :description)
      refute Map.has_key?(payload, :photo_url)
    end

    test "has_photo is false when photo_url is nil" do
      report = %IncidentReport{
        id: "r2",
        provider_profile_id: "prov-1",
        reporter_user_id: "user-uuid",
        program_id: "prog-1",
        session_id: nil,
        category: :other,
        severity: :low,
        description: "Nothing special",
        occurred_at: ~U[2026-04-20 10:00:00Z],
        photo_url: nil,
        original_filename: nil
      }

      assert %DomainEvent{payload: %{has_photo: false}} = ProviderEvents.incident_reported(report)
    end

    test "forwards opts to DomainEvent.new/5 (e.g., correlation_id)" do
      report = %IncidentReport{
        id: "r3",
        provider_profile_id: "prov-1",
        reporter_user_id: "user-uuid",
        program_id: "prog-1",
        session_id: nil,
        category: :other,
        severity: :low,
        description: "Just checking opts forwarding.",
        occurred_at: ~U[2026-04-20 10:00:00Z],
        photo_url: nil,
        original_filename: nil
      }

      correlation_id = Ecto.UUID.generate()

      event = ProviderEvents.incident_reported(report, correlation_id: correlation_id)

      assert event.metadata.correlation_id == correlation_id
    end
  end
end
