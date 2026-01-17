defmodule KlassHero.Community.EventPublisher do
  @moduledoc """
  Convenience module for publishing Community context domain events.

  Provides thin wrappers around the generic event publishing infrastructure
  for post-related events. Uses dependency injection to allow testing with
  mock publishers.

  ## Configuration

  The publisher module is configured in application config:

      config :klass_hero, :event_publisher,
        module: KlassHero.Shared.Adapters.Driven.Events.PubSubEventPublisher,
        pubsub: KlassHero.PubSub

  For tests, configure a test publisher:

      config :klass_hero, :event_publisher,
        module: KlassHero.Shared.Adapters.Driven.Events.TestEventPublisher,
        pubsub: KlassHero.PubSub

  ## Usage

      alias KlassHero.Community.EventPublisher

      # After a comment is added
      EventPublisher.publish_comment_added(post, author, comment_text)

      # After a post is liked
      EventPublisher.publish_post_liked(post)

      # After a post is unliked
      EventPublisher.publish_post_unliked(post)
  """

  alias KlassHero.Community.Domain.Events.CommunityEvents
  alias KlassHero.Community.Domain.Models.Post
  alias KlassHero.Shared.EventPublishing

  @doc """
  Publishes a `comment_added` event.

  ## Parameters

  - `post` - The Post struct that received the comment
  - `author` - The author of the comment
  - `comment_text` - The text content of the comment
  - `opts` - Options passed to event creation
    - `:correlation_id` - ID to correlate related events
    - Any other metadata options

  ## Examples

      EventPublisher.publish_comment_added(post, "John Doe", "Great post!")

  ## Returns

  - `:ok` on successful publish
  - `{:error, reason}` on failure
  """
  @spec publish_comment_added(Post.t(), String.t(), String.t(), keyword()) ::
          :ok | {:error, term()}
  def publish_comment_added(%Post{} = post, author, comment_text, opts \\ []) do
    post
    |> CommunityEvents.comment_added(author, comment_text, %{}, opts)
    |> EventPublishing.publish()
  end

  @doc """
  Publishes a `post_liked` event.

  ## Parameters

  - `post` - The Post struct that was liked
  - `opts` - Options passed to event creation
    - `:correlation_id` - ID to correlate related events
    - Any other metadata options

  ## Examples

      EventPublisher.publish_post_liked(post)

  ## Returns

  - `:ok` on successful publish
  - `{:error, reason}` on failure
  """
  @spec publish_post_liked(Post.t(), keyword()) :: :ok | {:error, term()}
  def publish_post_liked(%Post{} = post, opts \\ []) do
    post
    |> CommunityEvents.post_liked(%{}, opts)
    |> EventPublishing.publish()
  end

  @doc """
  Publishes a `post_unliked` event.

  ## Parameters

  - `post` - The Post struct that was unliked
  - `opts` - Options passed to event creation
    - `:correlation_id` - ID to correlate related events
    - Any other metadata options

  ## Examples

      EventPublisher.publish_post_unliked(post)

  ## Returns

  - `:ok` on successful publish
  - `{:error, reason}` on failure
  """
  @spec publish_post_unliked(Post.t(), keyword()) :: :ok | {:error, term()}
  def publish_post_unliked(%Post{} = post, opts \\ []) do
    post
    |> CommunityEvents.post_unliked(%{}, opts)
    |> EventPublishing.publish()
  end
end
