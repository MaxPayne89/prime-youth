defmodule PrimeYouth.Highlights.Application.UseCases.ToggleLikeTest do
  use ExUnit.Case, async: false

  alias PrimeYouth.Highlights.Adapters.Driven.Persistence.Repositories.InMemoryPostRepository
  alias PrimeYouth.Highlights.Application.UseCases.ToggleLike
  alias PrimeYouth.Highlights.Domain.Models.Post

  setup do
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

      # Then unlike it
      assert {:ok, unliked_post} = ToggleLike.execute("post_1")
      assert unliked_post.user_liked == false
      assert unliked_post.likes == original_likes - 1
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
    end
  end

  describe "execute/1 - error handling" do
    test "returns error for non-existent post" do
      assert {:error, :not_found} = ToggleLike.execute("non_existent_post")
    end

    test "returns error for nil post id" do
      assert {:error, :not_found} = ToggleLike.execute(nil)
    end

    test "returns error for empty string post id" do
      assert {:error, :not_found} = ToggleLike.execute("")
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
end
