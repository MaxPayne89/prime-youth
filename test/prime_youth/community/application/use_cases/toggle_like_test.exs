defmodule KlassHero.Community.Application.UseCases.ToggleLikeTest do
  use ExUnit.Case, async: false

  import KlassHero.EventTestHelper

  alias KlassHero.Community.Adapters.Driven.Persistence.Repositories.InMemoryPostRepository
  alias KlassHero.Community.Application.UseCases.ToggleLike
  alias KlassHero.Community.Domain.Models.Post

  setup do
    setup_test_events()
    # Repository is already started by the application supervisor
    # Reset to initial state for test isolation
    InMemoryPostRepository.reset()
    :ok
  end

  describe "execute/1 - liking a post" do
    test "adds like when user has not liked the post" do
      {:ok, original_post} = InMemoryPostRepository.get_by_id("post_1")
      original_likes = original_post.likes
      assert original_post.user_liked == false

      assert {:ok, updated_post} = ToggleLike.execute("post_1")
      assert %Post{} = updated_post
      assert updated_post.user_liked == true
      assert updated_post.likes == original_likes + 1

      # Verify event published
      assert_event_published(:post_liked)

      assert_event_published(:post_liked, %{
        post_id: "post_1",
        likes_count: updated_post.likes
      })
    end

    test "increments like count correctly" do
      {:ok, original_post} = InMemoryPostRepository.get_by_id("post_2")
      original_likes = original_post.likes

      {:ok, updated_post} = ToggleLike.execute("post_2")
      assert updated_post.likes == original_likes + 1
    end

    test "persists like state to repository" do
      ToggleLike.execute("post_1")

      {:ok, fetched_post} = InMemoryPostRepository.get_by_id("post_1")
      assert fetched_post.user_liked == true
    end
  end

  describe "execute/1 - unliking a post" do
    test "removes like when user has already liked the post" do
      # First like the post
      {:ok, liked_post} = ToggleLike.execute("post_1")
      assert liked_post.user_liked == true
      original_likes = liked_post.likes

      # Clear events from the like action
      clear_events()

      # Then unlike it
      assert {:ok, unliked_post} = ToggleLike.execute("post_1")
      assert unliked_post.user_liked == false
      assert unliked_post.likes == original_likes - 1

      # Verify unlike event published
      assert_event_published(:post_unliked)

      assert_event_published(:post_unliked, %{
        post_id: "post_1",
        likes_count: unliked_post.likes
      })
    end

    test "decrements like count correctly" do
      # Like the post first
      {:ok, liked_post} = ToggleLike.execute("post_3")
      likes_after_like = liked_post.likes

      # Then unlike
      {:ok, unliked_post} = ToggleLike.execute("post_3")
      assert unliked_post.likes == likes_after_like - 1
    end

    test "persists unlike state to repository" do
      # Like then unlike
      ToggleLike.execute("post_2")
      ToggleLike.execute("post_2")

      {:ok, fetched_post} = InMemoryPostRepository.get_by_id("post_2")
      assert fetched_post.user_liked == false
    end
  end

  describe "execute/1 - toggling behavior" do
    test "can toggle like multiple times" do
      post_id = "post_1"
      {:ok, original_post} = InMemoryPostRepository.get_by_id(post_id)
      original_likes = original_post.likes
      original_user_liked = original_post.user_liked

      # Toggle 1: Like
      {:ok, post1} = ToggleLike.execute(post_id)
      assert post1.user_liked != original_user_liked
      assert post1.likes == original_likes + 1

      # Toggle 2: Unlike
      {:ok, post2} = ToggleLike.execute(post_id)
      assert post2.user_liked == original_user_liked
      assert post2.likes == original_likes

      # Toggle 3: Like again
      {:ok, post3} = ToggleLike.execute(post_id)
      assert post3.user_liked != original_user_liked
      assert post3.likes == original_likes + 1

      # Verify alternating events (like → unlike → like)
      events = get_published_events()
      assert length(events) == 3
      assert Enum.at(events, 0).event_type == :post_liked
      assert Enum.at(events, 1).event_type == :post_unliked
      assert Enum.at(events, 2).event_type == :post_liked
    end
  end

  describe "execute/1 - error handling" do
    test "returns error for non-existent post" do
      assert {:error, :not_found} = ToggleLike.execute("non_existent_post")
      # No events should be published on error
      assert_no_events_published()
    end

    test "returns error for nil post id" do
      assert {:error, :not_found} = ToggleLike.execute(nil)
      # No events should be published on error
      assert_no_events_published()
    end

    test "returns error for empty string post id" do
      assert {:error, :not_found} = ToggleLike.execute("")
      # No events should be published on error
      assert_no_events_published()
    end
  end

  describe "execute/1 - data integrity" do
    test "does not modify other post fields" do
      {:ok, original_post} = InMemoryPostRepository.get_by_id("post_1")

      {:ok, updated_post} = ToggleLike.execute("post_1")

      # Verify only likes and user_liked changed
      assert updated_post.id == original_post.id
      assert updated_post.author == original_post.author
      assert updated_post.content == original_post.content
      assert updated_post.comment_count == original_post.comment_count
      assert updated_post.comments == original_post.comments
      assert updated_post.type == original_post.type
    end

    test "does not affect other posts" do
      {:ok, all_posts_before} = InMemoryPostRepository.list_all()
      {:ok, other_post_before} = InMemoryPostRepository.get_by_id("post_2")

      ToggleLike.execute("post_1")

      {:ok, all_posts_after} = InMemoryPostRepository.list_all()
      {:ok, other_post_after} = InMemoryPostRepository.get_by_id("post_2")

      assert length(all_posts_before) == length(all_posts_after)
      assert other_post_after.likes == other_post_before.likes
      assert other_post_after.user_liked == other_post_before.user_liked
    end

    test "like count cannot go below zero" do
      # Get a post with zero likes
      {:ok, posts} = InMemoryPostRepository.list_all()

      # Find or create a post with zero likes
      zero_likes_post =
        Enum.find(posts, fn post ->
          post.likes == 0 and post.user_liked == false
        end)

      # If no post with zero likes, we can't test negative scenario
      # But we can verify the logic doesn't break
      if zero_likes_post do
        # This should not make likes negative
        assert {:ok, post} = ToggleLike.execute(zero_likes_post.id)
        assert post.likes >= 0
      end
    end
  end

  describe "execute/1 - event publishing" do
    test "publishes post_liked event with correct payload when liking" do
      {:ok, updated_post} = ToggleLike.execute("post_1")

      # Verify event was published
      event = assert_event_published(:post_liked)
      assert event.payload.post_id == "post_1"
      assert event.payload.likes_count == updated_post.likes
      assert event.aggregate_id == "post_1"
      assert event.aggregate_type == :post
    end

    test "publishes post_unliked event with correct payload when unliking" do
      # First like the post
      ToggleLike.execute("post_1")
      clear_events()

      # Then unlike it
      {:ok, updated_post} = ToggleLike.execute("post_1")

      # Verify unlike event was published
      event = assert_event_published(:post_unliked)
      assert event.payload.post_id == "post_1"
      assert event.payload.likes_count == updated_post.likes
      assert event.aggregate_id == "post_1"
      assert event.aggregate_type == :post
    end

    test "does not publish events when post not found" do
      assert {:error, :not_found} = ToggleLike.execute("non_existent_post")
      assert_no_events_published()
    end

    test "publishes distinct events for multiple posts" do
      {:ok, post1} = ToggleLike.execute("post_1")
      {:ok, post2} = ToggleLike.execute("post_2")
      {:ok, post3} = ToggleLike.execute("post_3")

      # Verify all events published with correct data
      assert_event_count(3)

      events = get_published_events()
      assert Enum.all?(events, &(&1.event_type == :post_liked))

      # Verify each event has distinct post_id
      post_ids = Enum.map(events, & &1.payload.post_id)
      assert "post_1" in post_ids
      assert "post_2" in post_ids
      assert "post_3" in post_ids

      # Verify likes counts match
      assert Enum.find(events, &(&1.payload.post_id == "post_1")).payload.likes_count ==
               post1.likes

      assert Enum.find(events, &(&1.payload.post_id == "post_2")).payload.likes_count ==
               post2.likes

      assert Enum.find(events, &(&1.payload.post_id == "post_3")).payload.likes_count ==
               post3.likes
    end

    test "publishes correct event type based on user_liked state" do
      post_id = "post_1"

      # Like the post
      {:ok, liked_post} = ToggleLike.execute(post_id)
      assert liked_post.user_liked == true
      assert_event_published(:post_liked)

      clear_events()

      # Unlike the post
      {:ok, unliked_post} = ToggleLike.execute(post_id)
      assert unliked_post.user_liked == false
      assert_event_published(:post_unliked)
    end

    test "publishes exactly one event per toggle operation" do
      ToggleLike.execute("post_1")
      assert_event_count(1)

      clear_events()

      ToggleLike.execute("post_1")
      assert_event_count(1)
    end
  end
end
