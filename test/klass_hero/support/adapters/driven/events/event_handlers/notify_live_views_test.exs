defmodule KlassHero.Support.Adapters.Driven.Events.EventHandlers.NotifyLiveViewsTest do
  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Support.Adapters.Driven.Events.EventHandlers.NotifyLiveViews
  alias KlassHero.Shared.Domain.Events.DomainEvent

  setup do
    setup_test_events()
    :ok
  end

  describe "handle/1" do
    test "publishes contact_request_submitted to derived topic" do
      request_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:contact_request_submitted, request_id, :contact_request, %{
          request_id: request_id,
          email: "help@example.com"
        })

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:contact_request_submitted)
    end
  end

  describe "derive_topic/1" do
    test "builds topic from aggregate_type and event_type" do
      event = DomainEvent.new(:contact_request_submitted, "id", :contact_request, %{})

      assert NotifyLiveViews.derive_topic(event) ==
               "contact_request:contact_request_submitted"
    end
  end

  describe "build_topic/2" do
    test "builds topic string" do
      assert NotifyLiveViews.build_topic(:contact_request, :contact_request_submitted) ==
               "contact_request:contact_request_submitted"
    end
  end
end
