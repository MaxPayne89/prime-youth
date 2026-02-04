defmodule KlassHero.Community.Adapters.Driven.Events.EventHandlers.NotifyLiveViewsTest do
  use ExUnit.Case, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.Community.Adapters.Driven.Events.EventHandlers.NotifyLiveViews
  alias KlassHero.Shared.Domain.Events.DomainEvent

  setup do
    setup_test_events()
    :ok
  end

  describe "handle/1" do
    test "publishes comment_added to derived topic" do
      post_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:comment_added, post_id, :post, %{
          post_id: post_id,
          author: "John",
          comment_text: "Nice"
        })

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:comment_added)
    end

    test "publishes post_liked to derived topic" do
      post_id = Ecto.UUID.generate()
      event = DomainEvent.new(:post_liked, post_id, :post, %{post_id: post_id})

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:post_liked)
    end

    test "publishes post_unliked to derived topic" do
      post_id = Ecto.UUID.generate()
      event = DomainEvent.new(:post_unliked, post_id, :post, %{post_id: post_id})

      assert :ok = NotifyLiveViews.handle(event)
      assert_event_published(:post_unliked)
    end
  end

  describe "derive_topic/1" do
    test "builds topic from aggregate_type and event_type" do
      event = DomainEvent.new(:post_liked, "id", :post, %{})
      assert NotifyLiveViews.derive_topic(event) == "post:post_liked"
    end
  end

  describe "build_topic/2" do
    test "builds topic string from atoms" do
      assert NotifyLiveViews.build_topic(:post, :post_liked) == "post:post_liked"
    end
  end
end
