defmodule PrimeYouth.Highlights.Application.UseCases.AddCommentTest do
  use ExUnit.Case, async: false

  alias PrimeYouth.Highlights.Adapters.Driven.Persistence.Repositories.InMemoryPostRepository
  alias PrimeYouth.Highlights.Application.UseCases.AddComment
  alias PrimeYouth.Highlights.Domain.Models.{Post, Comment}

  setup do
    # Repository is already started by the application supervisor
    # Reset to initial state for test isolation
    InMemoryPostRepository.reset()
    :ok
  end

  describe "execute/3 - adding comments" do
    test "adds comment to post successfully" do
      {:ok, original_post} = InMemoryPostRepository.get_by_id("post_1")
      original_comment_count = length(original_post.comments)

      assert {:ok, updated_post} =
               AddComment.execute("post_1", "This is a test comment", "Test User")

      assert %Post{} = updated_post
      assert length(updated_post.comments) == original_comment_count + 1
    end

    test "comment has correct author and text" do
      {:ok, updated_post} = AddComment.execute("post_2", "Great post!", "John Doe")

      new_comment = List.last(updated_post.comments)
      assert %Comment{} = new_comment
      assert new_comment.author == "John Doe"
      assert new_comment.text == "Great post!"
    end

    test "increments comment count" do
      {:ok, original_post} = InMemoryPostRepository.get_by_id("post_3")
      original_count = original_post.comment_count

      {:ok, updated_post} = AddComment.execute("post_3", "Nice!", "User")

      assert updated_post.comment_count == original_count + 1
    end

    test "persists comment to repository" do
      AddComment.execute("post_1", "Persistent comment", "Tester")

      {:ok, fetched_post} = InMemoryPostRepository.get_by_id("post_1")
      comment = List.last(fetched_post.comments)
      assert comment.text == "Persistent comment"
      assert comment.author == "Tester"
    end

    test "appends comment to end of list" do
      {:ok, original_post} = InMemoryPostRepository.get_by_id("post_1")
      original_comments = original_post.comments

      AddComment.execute("post_1", "New comment", "User")

      {:ok, updated_post} = InMemoryPostRepository.get_by_id("post_1")
      new_comment = List.last(updated_post.comments)

      # Verify all original comments are still there
      assert length(updated_post.comments) == length(original_comments) + 1
      assert new_comment.text == "New comment"
    end
  end

  describe "execute/3 - multiple comments" do
    test "can add multiple comments to same post" do
      post_id = "post_2"
      {:ok, original_post} = InMemoryPostRepository.get_by_id(post_id)
      original_count = original_post.comment_count

      AddComment.execute(post_id, "First comment", "User1")
      AddComment.execute(post_id, "Second comment", "User2")
      {:ok, updated_post} = AddComment.execute(post_id, "Third comment", "User3")

      assert updated_post.comment_count == original_count + 3
      assert length(updated_post.comments) == original_count + 3

      # Verify all comments are present
      comment_texts = Enum.map(updated_post.comments, & &1.text)
      assert "First comment" in comment_texts
      assert "Second comment" in comment_texts
      assert "Third comment" in comment_texts
    end

    test "preserves order of comments" do
      post_id = "post_3"

      AddComment.execute(post_id, "Comment 1", "User1")
      AddComment.execute(post_id, "Comment 2", "User2")
      {:ok, updated_post} = AddComment.execute(post_id, "Comment 3", "User3")

      comments = updated_post.comments
      last_three = Enum.take(comments, -3)

      assert Enum.at(last_three, 0).text == "Comment 1"
      assert Enum.at(last_three, 1).text == "Comment 2"
      assert Enum.at(last_three, 2).text == "Comment 3"
    end
  end

  describe "execute/3 - different comment content" do
    test "handles empty comment text" do
      {:ok, updated_post} = AddComment.execute("post_1", "", "User")
      comment = List.last(updated_post.comments)
      assert comment.text == ""
    end

    test "handles long comment text" do
      long_text = String.duplicate("a", 1000)
      {:ok, updated_post} = AddComment.execute("post_1", long_text, "User")
      comment = List.last(updated_post.comments)
      assert comment.text == long_text
    end

    test "handles special characters in comment" do
      special_text = "Test 🎉 with emoji & symbols @#$%"
      {:ok, updated_post} = AddComment.execute("post_2", special_text, "User")
      comment = List.last(updated_post.comments)
      assert comment.text == special_text
    end

    test "handles multiline comment text" do
      multiline = "Line 1\nLine 2\nLine 3"
      {:ok, updated_post} = AddComment.execute("post_3", multiline, "User")
      comment = List.last(updated_post.comments)
      assert comment.text == multiline
    end
  end

  describe "execute/3 - different authors" do
    test "handles empty author name" do
      {:ok, updated_post} = AddComment.execute("post_1", "Comment", "")
      comment = List.last(updated_post.comments)
      assert comment.author == ""
    end

    test "handles special characters in author name" do
      author = "John 🚀 Doe @johndoe"
      {:ok, updated_post} = AddComment.execute("post_2", "Comment", author)
      comment = List.last(updated_post.comments)
      assert comment.author == author
    end
  end

  describe "execute/3 - error handling" do
    test "returns error for non-existent post" do
      assert {:error, :not_found} =
               AddComment.execute("non_existent", "Comment", "User")
    end

    test "returns error for nil post id" do
      assert {:error, :not_found} = AddComment.execute(nil, "Comment", "User")
    end

    test "returns error for empty string post id" do
      assert {:error, :not_found} = AddComment.execute("", "Comment", "User")
    end
  end

  describe "execute/3 - data integrity" do
    test "does not modify other post fields" do
      {:ok, original_post} = InMemoryPostRepository.get_by_id("post_1")

      {:ok, updated_post} = AddComment.execute("post_1", "Comment", "User")

      # Verify only comments and comment_count changed
      assert updated_post.id == original_post.id
      assert updated_post.author == original_post.author
      assert updated_post.content == original_post.content
      assert updated_post.likes == original_post.likes
      assert updated_post.user_liked == original_post.user_liked
      assert updated_post.type == original_post.type
    end

    test "does not affect other posts" do
      {:ok, all_posts_before} = InMemoryPostRepository.list_all()
      {:ok, other_post_before} = InMemoryPostRepository.get_by_id("post_2")

      AddComment.execute("post_1", "Comment", "User")

      {:ok, all_posts_after} = InMemoryPostRepository.list_all()
      {:ok, other_post_after} = InMemoryPostRepository.get_by_id("post_2")

      assert length(all_posts_before) == length(all_posts_after)
      assert length(other_post_after.comments) == length(other_post_before.comments)
      assert other_post_after.comment_count == other_post_before.comment_count
    end

    test "comment count matches actual comments length" do
      post_id = "post_3"

      AddComment.execute(post_id, "C1", "U1")
      AddComment.execute(post_id, "C2", "U2")
      {:ok, updated_post} = AddComment.execute(post_id, "C3", "U3")

      assert updated_post.comment_count == length(updated_post.comments)
    end
  end

  describe "execute/3 - edge cases" do
    test "handles rapid sequential comments" do
      post_id = "post_1"

      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            AddComment.execute(post_id, "Comment #{i}", "User#{i}")
          end)
        end

      results = Task.await_many(tasks, 5000)
      assert Enum.all?(results, &match?({:ok, %Post{}}, &1))

      # Final check - verify all comments were added
      {:ok, final_post} = InMemoryPostRepository.get_by_id(post_id)
      assert final_post.comment_count == length(final_post.comments)
    end
  end
end
