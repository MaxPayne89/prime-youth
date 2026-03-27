defmodule KlassHero.Participation.Adapters.Driving.Events.EventHandlers.NotifyLiveViewsTest do
  use KlassHero.DataCase, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Participation.Adapters.Driving.Events.EventHandlers.NotifyLiveViews
  alias KlassHero.Shared.Domain.Events.DomainEvent

  setup do
    setup_test_events()
    :ok
  end

  describe "handle/1 — events with valid program_id" do
    test "returns :ok and publishes event for session_created" do
      provider = KlassHero.Factory.insert(:provider_profile_schema)
      program = KlassHero.Factory.insert(:program_schema, provider_id: provider.id)
      session_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:session_created, session_id, :participation, %{
          session_id: session_id,
          program_id: program.id
        })

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:session_created)
    end

    test "returns :ok and publishes event for child_checked_in" do
      provider = KlassHero.Factory.insert(:provider_profile_schema)
      program = KlassHero.Factory.insert(:program_schema, provider_id: provider.id)

      event =
        DomainEvent.new(:child_checked_in, Ecto.UUID.generate(), :participation, %{
          record_id: Ecto.UUID.generate(),
          session_id: Ecto.UUID.generate(),
          child_id: Ecto.UUID.generate(),
          program_id: program.id
        })

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:child_checked_in)
    end
  end

  describe "handle/1 — graceful degradation" do
    test "returns :ok when program_id does not exist (provider-specific publish skipped)" do
      event =
        DomainEvent.new(:session_started, Ecto.UUID.generate(), :participation, %{
          session_id: Ecto.UUID.generate(),
          program_id: Ecto.UUID.generate()
        })

      assert :ok = NotifyLiveViews.handle(event)
      # Generic topic publish still happened
      assert_event_published(:session_started)
    end

    test "returns :ok when payload has no program_id" do
      event =
        DomainEvent.new(:session_created, Ecto.UUID.generate(), :participation, %{
          session_id: Ecto.UUID.generate()
        })

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:session_created)
    end
  end
end
