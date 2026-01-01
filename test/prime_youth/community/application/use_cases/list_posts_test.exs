defmodule PrimeYouth.Community.Application.UseCases.ListPostsTest do
  use ExUnit.Case, async: false

  alias PrimeYouth.Community.Adapters.Driven.Persistence.Repositories.InMemoryPostRepository
  alias PrimeYouth.Community.Application.UseCases.ListPosts
  alias PrimeYouth.Community.Domain.Models.Post

  setup do
    # Repository is already started by the application supervisor
    # Reset to initial state for test isolation
    InMemoryPostRepository.reset()
    :ok
  end

  describe "execute/0" do
    test "returns list of posts" do
      assert {:ok, posts} = ListPosts.execute()
      assert is_list(posts)
      assert length(posts) == 3
      assert Enum.all?(posts, &match?(%Post{}, &1))
    end

    test "returns posts with correct structure" do
      assert {:ok, [post | _]} = ListPosts.execute()

      assert is_binary(post.id)
      assert is_binary(post.author)
      assert is_binary(post.content)
      assert is_integer(post.likes)
      assert is_integer(post.comment_count)
      assert is_boolean(post.user_liked)
      assert is_list(post.comments)
      assert post.type in [:photo, :text, :event]
    end

    test "returns all expected posts" do
      assert {:ok, posts} = ListPosts.execute()

      post_ids = Enum.map(posts, & &1.id)
      assert "post_1" in post_ids
      assert "post_2" in post_ids
      assert "post_3" in post_ids
    end

    test "returns posts with correct authors" do
      assert {:ok, posts} = ListPosts.execute()

      authors = Enum.map(posts, & &1.author)
      assert "Ms. Sarah - Art Instructor" in authors
      assert "Mr. David - Chess Coach" in authors
      assert "Prime Youth Admin" in authors
    end

    test "posts contain engagement metrics" do
      assert {:ok, posts} = ListPosts.execute()

      Enum.each(posts, fn post ->
        assert is_integer(post.likes)
        assert post.likes >= 0
        assert is_integer(post.comment_count)
        assert post.comment_count >= 0
        assert is_boolean(post.user_liked)
      end)
    end

    test "posts with comments include comment data" do
      assert {:ok, posts} = ListPosts.execute()

      post_with_comments = Enum.find(posts, &(not Enum.empty?(&1.comments)))
      assert post_with_comments != nil

      comment = List.first(post_with_comments.comments)
      assert is_binary(comment.author)
      assert is_binary(comment.text)
    end

    test "different post types are represented" do
      assert {:ok, posts} = ListPosts.execute()

      types = Enum.map(posts, & &1.type) |> Enum.uniq()
      assert :photo in types
      assert :text in types
      assert :event in types
    end
  end

  describe "integration with repository" do
    test "reflects repository state changes" do
      # Get initial posts
      {:ok, initial_posts} = ListPosts.execute()
      initial_post = Enum.find(initial_posts, &(&1.id == "post_1"))

      # Update a post through repository
      updated_post = %{initial_post | likes: 999}
      InMemoryPostRepository.update(updated_post)

      # Verify use case returns updated data
      {:ok, new_posts} = ListPosts.execute()
      updated = Enum.find(new_posts, &(&1.id == "post_1"))
      assert updated.likes == 999
    end
  end
end
