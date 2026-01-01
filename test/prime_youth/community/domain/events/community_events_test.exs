defmodule PrimeYouth.Community.Domain.Events.CommunityEventsTest do
  use ExUnit.Case, async: true

  alias PrimeYouth.Community.Domain.Events.CommunityEvents
  alias PrimeYouth.Community.Domain.Models.Post

  # Helper to create a valid post with only required overrides
  defp valid_post(overrides \\ []) do
    defaults = [
      id: "post_1",
      author: "John Doe",
      avatar_bg: "bg-blue-500",
      avatar_emoji: "🎯",
      timestamp: "2 hours ago",
      content: "Test post content",
      type: :text,
      likes: 0,
      comment_count: 0,
      user_liked: false,
      comments: []
    ]

    struct(Post, Keyword.merge(defaults, overrides))
  end

  describe "comment_added/5 validation" do
    test "raises when author is empty string via guard clause" do
      post = valid_post()

      assert_raise FunctionClauseError, fn ->
        CommunityEvents.comment_added(post, "", "Great post!")
      end
    end

    test "raises when author is not a binary via guard clause" do
      post = valid_post()

      assert_raise FunctionClauseError, fn ->
        CommunityEvents.comment_added(post, nil, "Great post!")
      end
    end

    test "raises when comment_text is empty string via guard clause" do
      post = valid_post()

      assert_raise FunctionClauseError, fn ->
        CommunityEvents.comment_added(post, "John", "")
      end
    end

    test "raises when comment_text is not a binary via guard clause" do
      post = valid_post()

      assert_raise FunctionClauseError, fn ->
        CommunityEvents.comment_added(post, "John", nil)
      end
    end

    test "raises when post.id is nil" do
      post = valid_post(id: nil)

      assert_raise ArgumentError,
                   "Post.id cannot be nil or empty",
                   fn -> CommunityEvents.comment_added(post, "John", "Great post!") end
    end

    test "raises when post.id is empty string" do
      post = valid_post(id: "")

      assert_raise ArgumentError,
                   "Post.id cannot be nil or empty",
                   fn -> CommunityEvents.comment_added(post, "John", "Great post!") end
    end

    test "succeeds with valid post and parameters" do
      post = valid_post(comment_count: 3, likes: 15)

      event = CommunityEvents.comment_added(post, "John", "Great post!")

      assert event.event_type == :comment_added
      assert event.aggregate_id == "post_1"
      assert event.aggregate_type == :post
      assert event.payload.post_id == "post_1"
      assert event.payload.author == "John"
      assert event.payload.comment_text == "Great post!"
    end

    test "succeeds with valid post and custom payload" do
      post = valid_post(comment_count: 3, likes: 15)

      event =
        CommunityEvents.comment_added(post, "John", "Great post!", %{user_id: 123})

      assert event.payload.user_id == 123
    end
  end

  describe "post_liked/3 validation" do
    test "raises when post.id is nil" do
      post = valid_post(id: nil, likes: 15)

      assert_raise ArgumentError,
                   "Post.id cannot be nil or empty",
                   fn -> CommunityEvents.post_liked(post) end
    end

    test "raises when post.id is empty string" do
      post = valid_post(id: "", likes: 15)

      assert_raise ArgumentError,
                   "Post.id cannot be nil or empty",
                   fn -> CommunityEvents.post_liked(post) end
    end

    test "raises when post.likes is nil" do
      post = valid_post(likes: nil)

      assert_raise ArgumentError,
                   ~r/Post.likes must be a non-negative integer/,
                   fn -> CommunityEvents.post_liked(post) end
    end

    test "raises when post.likes is negative" do
      post = valid_post(likes: -5)

      assert_raise ArgumentError,
                   "Post.likes must be a non-negative integer, got: -5",
                   fn -> CommunityEvents.post_liked(post) end
    end

    test "raises when post.likes is not an integer" do
      post = valid_post(likes: "15")

      assert_raise ArgumentError,
                   ~r/Post.likes must be a non-negative integer/,
                   fn -> CommunityEvents.post_liked(post) end
    end

    test "succeeds with valid post" do
      post = valid_post(likes: 15)

      event = CommunityEvents.post_liked(post)

      assert event.event_type == :post_liked
      assert event.aggregate_id == "post_1"
      assert event.aggregate_type == :post
      assert event.payload.post_id == "post_1"
      assert event.payload.likes_count == 15
    end

    test "succeeds with valid post and zero likes" do
      post = valid_post(likes: 0)

      event = CommunityEvents.post_liked(post)

      assert event.payload.likes_count == 0
    end

    test "succeeds with valid post and custom payload" do
      post = valid_post(likes: 15)

      event = CommunityEvents.post_liked(post, %{user_id: 123})

      assert event.payload.user_id == 123
    end
  end

  describe "post_unliked/3 validation" do
    test "raises when post.id is nil" do
      post = valid_post(id: nil, likes: 14)

      assert_raise ArgumentError,
                   "Post.id cannot be nil or empty",
                   fn -> CommunityEvents.post_unliked(post) end
    end

    test "raises when post.id is empty string" do
      post = valid_post(id: "", likes: 14)

      assert_raise ArgumentError,
                   "Post.id cannot be nil or empty",
                   fn -> CommunityEvents.post_unliked(post) end
    end

    test "raises when post.likes is nil" do
      post = valid_post(likes: nil)

      assert_raise ArgumentError,
                   ~r/Post.likes must be a non-negative integer/,
                   fn -> CommunityEvents.post_unliked(post) end
    end

    test "raises when post.likes is negative" do
      post = valid_post(likes: -3)

      assert_raise ArgumentError,
                   "Post.likes must be a non-negative integer, got: -3",
                   fn -> CommunityEvents.post_unliked(post) end
    end

    test "raises when post.likes is not an integer" do
      post = valid_post(likes: "14")

      assert_raise ArgumentError,
                   ~r/Post.likes must be a non-negative integer/,
                   fn -> CommunityEvents.post_unliked(post) end
    end

    test "succeeds with valid post" do
      post = valid_post(likes: 14)

      event = CommunityEvents.post_unliked(post)

      assert event.event_type == :post_unliked
      assert event.aggregate_id == "post_1"
      assert event.aggregate_type == :post
      assert event.payload.post_id == "post_1"
      assert event.payload.likes_count == 14
    end

    test "succeeds with valid post and zero likes" do
      post = valid_post(likes: 0)

      event = CommunityEvents.post_unliked(post)

      assert event.payload.likes_count == 0
    end

    test "succeeds with valid post and custom payload" do
      post = valid_post(likes: 14)

      event = CommunityEvents.post_unliked(post, %{user_id: 123})

      assert event.payload.user_id == 123
    end
  end
end
