defmodule KlassHero.Community.Domain.Events.CommunityEvents do
  @moduledoc """
  Factory module for creating Community domain events.

  Provides convenience functions to create standardized DomainEvent structs
  for post-related events in the Community context.

  ## Events

  - `:comment_added` - Emitted when a comment is added to a post
  - `:post_liked` - Emitted when a post is liked
  - `:post_unliked` - Emitted when a post is unliked

  ## Validation

  Event factories perform fail-fast validation on all inputs:

  - **Aggregate validation**: Post fields must be present and valid
  - **Parameter validation**: String parameters must be non-empty
  - **Type validation**: All inputs must match expected types

  Validation failures raise `ArgumentError` with descriptive messages.

  ## Usage

      alias KlassHero.Community.Domain.Events.CommunityEvents

      # Create a comment_added event
      event = CommunityEvents.comment_added(post, "Author", "Comment text")

      # Create with additional metadata
      event = CommunityEvents.post_liked(post, %{}, correlation_id: "abc-123")

      # Invalid - raises ArgumentError
      event = CommunityEvents.comment_added(post, "", "Comment")
      #=> ** (ArgumentError) author parameter cannot be empty
  """

  alias KlassHero.Community.Domain.Models.Post
  alias KlassHero.Shared.Domain.Events.DomainEvent

  @aggregate_type :post

  @doc """
  Creates a `comment_added` event.

  ## Parameters

  - `post` - The Post struct that received the comment
  - `author` - The author of the comment
  - `comment_text` - The text content of the comment
  - `payload` - Additional event-specific data
  - `opts` - Metadata options (correlation_id, causation_id, user_id)

  ## Payload Fields

  Standard payload includes:
  - `post_id` - Post's unique identifier
  - `author` - Comment author's name
  - `comment_text` - The comment content

  ## Raises

  - `FunctionClauseError` if `author` is not a non-empty string
  - `FunctionClauseError` if `comment_text` is not a non-empty string
  - `ArgumentError` if `post.id` is nil or empty

  ## Examples

      iex> post = %Post{id: "post_1", comment_count: 3}
      iex> event = CommunityEvents.comment_added(post, "John", "Great post!")
      iex> event.event_type
      :comment_added
      iex> event.payload.author
      "John"
  """
  @spec comment_added(Post.t(), String.t(), String.t(), map(), keyword()) :: DomainEvent.t()
  def comment_added(%Post{} = post, author, comment_text, payload \\ %{}, opts \\ [])
      when is_binary(author) and byte_size(author) > 0 and is_binary(comment_text) and
             byte_size(comment_text) > 0 do
    validate_post!(post)

    base_payload = %{
      post_id: post.id,
      author: author,
      comment_text: comment_text,
      post: post
    }

    DomainEvent.new(
      :comment_added,
      post.id,
      @aggregate_type,
      Map.merge(base_payload, payload),
      opts
    )
  end

  @doc """
  Creates a `post_liked` event.

  Emitted when a user likes a post.

  ## Parameters

  - `post` - The Post struct that was liked
  - `payload` - Additional event-specific data
  - `opts` - Metadata options (correlation_id, causation_id, user_id)

  ## Payload Fields

  Standard payload includes:
  - `post_id` - Post's unique identifier
  - `likes_count` - Current number of likes after the action

  ## Raises

  - `ArgumentError` if `post.id` is nil or empty
  - `ArgumentError` if `post.likes` is not a non-negative integer

  ## Examples

      iex> post = %Post{id: "post_1", likes: 15}
      iex> event = CommunityEvents.post_liked(post)
      iex> event.event_type
      :post_liked
      iex> event.payload.likes_count
      15
  """
  @spec post_liked(Post.t(), map(), keyword()) :: DomainEvent.t()
  def post_liked(%Post{} = post, payload \\ %{}, opts \\ []) do
    validate_post_with_likes!(post)

    base_payload = %{
      post_id: post.id,
      likes_count: post.likes,
      post: post
    }

    DomainEvent.new(
      :post_liked,
      post.id,
      @aggregate_type,
      Map.merge(base_payload, payload),
      opts
    )
  end

  @doc """
  Creates a `post_unliked` event.

  Emitted when a user unlikes a post.

  ## Parameters

  - `post` - The Post struct that was unliked
  - `payload` - Additional event-specific data
  - `opts` - Metadata options (correlation_id, causation_id, user_id)

  ## Payload Fields

  Standard payload includes:
  - `post_id` - Post's unique identifier
  - `likes_count` - Current number of likes after the action

  ## Raises

  - `ArgumentError` if `post.id` is nil or empty
  - `ArgumentError` if `post.likes` is not a non-negative integer

  ## Examples

      iex> post = %Post{id: "post_1", likes: 14}
      iex> event = CommunityEvents.post_unliked(post)
      iex> event.event_type
      :post_unliked
      iex> event.payload.likes_count
      14
  """
  @spec post_unliked(Post.t(), map(), keyword()) :: DomainEvent.t()
  def post_unliked(%Post{} = post, payload \\ %{}, opts \\ []) do
    validate_post_with_likes!(post)

    base_payload = %{
      post_id: post.id,
      likes_count: post.likes,
      post: post
    }

    DomainEvent.new(
      :post_unliked,
      post.id,
      @aggregate_type,
      Map.merge(base_payload, payload),
      opts
    )
  end

  # Private validation functions

  defp validate_post!(%Post{id: id}) when is_nil(id) or id == "" do
    raise ArgumentError, "Post.id cannot be nil or empty"
  end

  defp validate_post!(%Post{} = post), do: post

  defp validate_post_with_likes!(%Post{id: id}) when is_nil(id) or id == "" do
    raise ArgumentError, "Post.id cannot be nil or empty"
  end

  defp validate_post_with_likes!(%Post{likes: likes}) when not is_integer(likes) or likes < 0 do
    raise ArgumentError,
          "Post.likes must be a non-negative integer, got: #{inspect(likes)}"
  end

  defp validate_post_with_likes!(%Post{} = post), do: post
end
