defmodule KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViewsTest do
  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews
  alias KlassHero.Shared.Domain.Events.DomainEvent

  setup do
    setup_test_events()
    :ok
  end

  describe "handle/1" do
    test "delegates to shared handler and publishes event" do
      session_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:session_created, session_id, :participation, %{
          session_id: session_id,
          program_id: Ecto.UUID.generate()
        })

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:session_created)
    end
  end

  describe "derive_topic/1" do
    test "delegates to shared handler" do
      event = DomainEvent.new(:session_created, "id", :participation, %{})
      assert NotifyLiveViews.derive_topic(event) == "participation:session_created"
    end
  end
end
