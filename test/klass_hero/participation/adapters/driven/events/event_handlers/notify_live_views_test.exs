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
    test "publishes session_created to derived topic" do
      session_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:session_created, session_id, :participation, %{
          session_id: session_id,
          program_id: Ecto.UUID.generate()
        })

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:session_created)
    end

    test "publishes child_checked_in to derived topic" do
      record_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:child_checked_in, record_id, :participation, %{
          record_id: record_id,
          session_id: Ecto.UUID.generate(),
          child_id: Ecto.UUID.generate()
        })

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:child_checked_in)
    end

    test "publishes behavioral_note_approved to derived topic" do
      note_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:behavioral_note_approved, note_id, :behavioral_note, %{
          note_id: note_id,
          status: :approved
        })

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:behavioral_note_approved)
    end
  end

  describe "derive_topic/1" do
    test "builds topic from aggregate_type and event_type" do
      event = DomainEvent.new(:session_created, "id", :participation, %{})
      assert NotifyLiveViews.derive_topic(event) == "participation:session_created"
    end
  end

  describe "build_topic/2" do
    test "builds topic string from atoms" do
      assert NotifyLiveViews.build_topic(:participation, :session_created) ==
               "participation:session_created"
    end
  end

  describe "error handling" do
    test "swallows publish failures and returns :ok" do
      event = DomainEvent.new(:session_started, "id", :participation, %{})
      assert :ok = NotifyLiveViews.handle(event)
    end
  end
end
