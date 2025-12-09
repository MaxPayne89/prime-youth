defmodule PrimeYouth.Highlights.Adapters.Driven.Persistence.Repositories.InMemoryPostRepositoryTest do
  use ExUnit.Case, async: false

  alias PrimeYouth.Highlights.Adapters.Driven.Persistence.Repositories.InMemoryPostRepository
  alias PrimeYouth.Highlights.Domain.Models.{Post, Comment}

  setup do
    # Repository is already started by the application supervisor
    # Reset to initial state for test isolation
    InMemoryPostRepository.reset()
    :ok
  end

  describe "list_all/0" do
    test "returns all initial posts" do
      assert {:ok, posts} = InMemoryPostRepository.list_all()
      assert length(posts) == 3
      assert Enum.all?(posts, &match?(%Post{}, &1))
    end

    test "posts have correct structure" do
      assert {:ok, [post | _]} = InMemoryPostRepository.list_all()
      assert is_binary(post.id)
      assert is_binary(post.author)
      assert is_binary(post.content)
      assert is_integer(post.likes)
      assert is_boolean(post.user_liked)
      assert is_list(post.comments)
    end
  end

  describe "get_by_id/1" do
    test "finds existing post by id" do
      assert {:ok, post} = InMemoryPostRepository.get_by_id("post_1")
      assert %Post{} = post
      assert post.id == "post_1"
      assert post.author == "Ms. Sarah - Art Instructor"
    end

    test "returns not_found for non-existent post" do
      assert {:error, :not_found} = InMemoryPostRepository.get_by_id("non_existent")
    end

    test "returns not_found for nil id" do
      assert {:error, :not_found} = InMemoryPostRepository.get_by_id(nil)
    end
  end

  describe "update/1" do
    test "updates existing post correctly" do
      {:ok, original_post} = InMemoryPostRepository.get_by_id("post_1")
      updated_post = %{original_post | likes: 99, user_liked: true}

      assert {:ok, returned_post} = InMemoryPostRepository.update(updated_post)
      assert returned_post.likes == 99
      assert returned_post.user_liked == true

      # Verify the update persisted
      {:ok, fetched_post} = InMemoryPostRepository.get_by_id("post_1")
      assert fetched_post.likes == 99
      assert fetched_post.user_liked == true
    end

    test "updates post comments" do
      {:ok, original_post} = InMemoryPostRepository.get_by_id("post_2")
      new_comment = %Comment{author: "Test User", text: "Test comment"}
      updated_post = %{original_post | comments: [new_comment], comment_count: 1}

      assert {:ok, _} = InMemoryPostRepository.update(updated_post)

      {:ok, fetched_post} = InMemoryPostRepository.get_by_id("post_2")
      assert length(fetched_post.comments) == 1
      assert fetched_post.comment_count == 1
      assert List.first(fetched_post.comments).text == "Test comment"
    end

    test "returns not_found for non-existent post" do
      non_existent_post = %Post{
        id: "non_existent",
        author: "Test",
        avatar_bg: "bg",
        avatar_emoji: "😀",
        timestamp: "now",
        content: "test",
        type: :text,
        likes: 0,
        comment_count: 0,
        user_liked: false,
        comments: []
      }

      assert {:error, :not_found} = InMemoryPostRepository.update(non_existent_post)
    end

    test "preserves other posts when updating one" do
      {:ok, all_posts_before} = InMemoryPostRepository.list_all()
      {:ok, post_to_update} = InMemoryPostRepository.get_by_id("post_1")
      updated_post = %{post_to_update | likes: 999}

      InMemoryPostRepository.update(updated_post)

      {:ok, all_posts_after} = InMemoryPostRepository.list_all()
      assert length(all_posts_before) == length(all_posts_after)

      # Verify other posts are unchanged
      {:ok, other_post} = InMemoryPostRepository.get_by_id("post_2")
      original_other = Enum.find(all_posts_before, &(&1.id == "post_2"))
      assert other_post.likes == original_other.likes
    end
  end

  describe "concurrent access" do
    test "handles concurrent reads" do
      tasks =
        for _ <- 1..10 do
          Task.async(fn -> InMemoryPostRepository.list_all() end)
        end

      results = Task.await_many(tasks)
      assert Enum.all?(results, &match?({:ok, [_, _, _]}, &1))
    end

    test "handles concurrent updates" do
      {:ok, post} = InMemoryPostRepository.get_by_id("post_1")

      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            updated = %{post | likes: post.likes + i}
            InMemoryPostRepository.update(updated)
          end)
        end

      results = Task.await_many(tasks)
      assert Enum.all?(results, &match?({:ok, %Post{}}, &1))
    end
  end
end
