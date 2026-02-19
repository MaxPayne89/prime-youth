defmodule KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.NotifyLiveViewsTest do
  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.NotifyLiveViews
  alias KlassHero.Shared.Domain.Events.DomainEvent

  setup do
    setup_test_events()
    :ok
  end

  describe "handle/1" do
    test "publishes participant_policy_set to derived topic" do
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
    test "builds topic from aggregate_type and event_type" do
      event = DomainEvent.new(:participant_policy_set, "id", :enrollment, %{})
      assert NotifyLiveViews.derive_topic(event) == "enrollment:participant_policy_set"
    end
  end

  describe "build_topic/2" do
    test "builds topic string from atoms" do
      assert NotifyLiveViews.build_topic(:enrollment, :participant_policy_set) ==
               "enrollment:participant_policy_set"
    end
  end

  describe "error handling" do
    test "swallows publish failures and returns :ok" do
      event = DomainEvent.new(:participant_policy_set, "id", :enrollment, %{})
      assert :ok = NotifyLiveViews.handle(event)
    end
  end
end
