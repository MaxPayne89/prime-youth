defmodule KlassHero.Enrollment.Adapters.Driving.Events.EventHandlers.NotifyLiveViewsTest do
  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Enrollment.Adapters.Driving.Events.EventHandlers.NotifyLiveViews
  alias KlassHero.Shared.Domain.Events.DomainEvent

  setup do
    setup_test_events()
    :ok
  end

  describe "handle/1" do
    test "delegates to shared handler and publishes event" do
      program_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:participant_policy_set, program_id, :enrollment, %{
          program_id: program_id
        })

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:participant_policy_set)
    end
  end

  describe "derive_topic/1" do
    test "delegates to shared handler" do
      event = DomainEvent.new(:participant_policy_set, "id", :enrollment, %{})
      assert NotifyLiveViews.derive_topic(event) == "enrollment:participant_policy_set"
    end
  end
end
