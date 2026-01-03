defmodule KlassHero.Community.Application.UseCases.AddCommentTest do
  use ExUnit.Case, async: false

  import KlassHero.EventTestHelper

  alias KlassHero.Community.Adapters.Driven.Persistence.Repositories.InMemoryPostRepository
  alias KlassHero.Community.Application.UseCases.AddComment
  alias KlassHero.Community.Domain.Models.{Comment, Post}

  setup do
    setup_test_events()
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

      # Verify event published
      assert_event_published(:comment_added)

      assert_event_published(:comment_added, %{
        post_id: "post_1",
        author: "Test User",
        comment_text: "This is a test comment"
      })
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

      # Verify all three events were published
      assert_event_count(3)
      events = get_published_events()
      assert Enum.all?(events, &(&1.event_type == :comment_added))

      # Verify each event has correct data
      comment_texts_from_events = Enum.map(events, & &1.payload.comment_text)
      assert "First comment" in comment_texts_from_events
      assert "Second comment" in comment_texts_from_events
      assert "Third comment" in comment_texts_from_events
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
    test "rejects empty comment text (validation in event factory)" do
      assert_raise FunctionClauseError, fn ->
        AddComment.execute("post_1", "", "User")
      end
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
    test "rejects empty author name (validation in event factory)" do
      assert_raise FunctionClauseError, fn ->
        AddComment.execute("post_1", "Comment", "")
      end
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

      # No events should be published on error
      assert_no_events_published()
    end

    test "returns error for nil post id" do
      assert {:error, :not_found} = AddComment.execute(nil, "Comment", "User")
      # No events should be published on error
      assert_no_events_published()
    end

    test "returns error for empty string post id" do
      assert {:error, :not_found} = AddComment.execute("", "Comment", "User")
      # No events should be published on error
      assert_no_events_published()
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

  describe "execute/3 - event publishing" do
    test "publishes comment_added event with correct payload" do
      {:ok, _updated_post} =
        AddComment.execute("post_1", "This is a test comment", "Test User")

      # Verify event was published
      event = assert_event_published(:comment_added)
      assert event.payload.post_id == "post_1"
      assert event.payload.author == "Test User"
      assert event.payload.comment_text == "This is a test comment"
      assert event.aggregate_id == "post_1"
      assert event.aggregate_type == :post
    end

    test "publishes events for different authors" do
      AddComment.execute("post_1", "Comment 1", "Alice")
      AddComment.execute("post_1", "Comment 2", "Bob")
      AddComment.execute("post_1", "Comment 3", "Charlie")

      assert_event_count(3)
      events = get_published_events()

      # Verify each event has correct author
      authors = Enum.map(events, & &1.payload.author)
      assert "Alice" in authors
      assert "Bob" in authors
      assert "Charlie" in authors
    end

    test "publishes events with different comment texts" do
      AddComment.execute("post_1", "First comment text", "User")
      AddComment.execute("post_1", "Second comment text", "User")

      assert_event_count(2)
      events = get_published_events()

      # Verify each event has correct text
      texts = Enum.map(events, & &1.payload.comment_text)
      assert "First comment text" in texts
      assert "Second comment text" in texts
    end

    test "does not publish events when post not found" do
      assert {:error, :not_found} =
               AddComment.execute("non_existent", "Comment", "User")

      assert_no_events_published()
    end

    test "publishes distinct events for multiple comments" do
      AddComment.execute("post_1", "Comment A", "User1")
      AddComment.execute("post_2", "Comment B", "User2")
      AddComment.execute("post_3", "Comment C", "User3")

      # Verify all events published with correct data
      assert_event_count(3)

      events = get_published_events()
      assert Enum.all?(events, &(&1.event_type == :comment_added))

      # Verify each event has correct post_id and comment text
      assert Enum.any?(events, fn e ->
               e.payload.post_id == "post_1" and e.payload.comment_text == "Comment A"
             end)

      assert Enum.any?(events, fn e ->
               e.payload.post_id == "post_2" and e.payload.comment_text == "Comment B"
             end)

      assert Enum.any?(events, fn e ->
               e.payload.post_id == "post_3" and e.payload.comment_text == "Comment C"
             end)
    end

    test "publishes exactly one event per comment added" do
      AddComment.execute("post_1", "Comment", "User")
      assert_event_count(1)

      clear_events()

      AddComment.execute("post_1", "Another comment", "User")
      assert_event_count(1)
    end

    test "publishes events with correct aggregate information" do
      {:ok, _post} = AddComment.execute("post_2", "Test comment", "Test Author")

      event = assert_event_published(:comment_added)
      assert event.aggregate_type == :post
      assert event.aggregate_id == "post_2"
    end
  end
end
