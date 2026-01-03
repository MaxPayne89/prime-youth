defmodule KlassHero.Community.Application.UseCases.ToggleLike do
  @moduledoc """
  Use case for toggling a like on a post.

  This use case implements the business logic for liking and unliking posts:
  - If the user has already liked the post: Remove the like and decrement the count
  - If the user has not liked the post: Add the like and increment the count

  ## Architecture

  This use case follows the Application Layer pattern in DDD/Ports & Adapters:
  - Contains business logic for like/unlike behavior
  - Coordinates repository operations (get, update)
  - Returns domain entities (Post structs)

  ## Dependency Injection

  The repository implementation is configured via Application config:

      config :klass_hero, :community,
        repository: KlassHero.Community.Adapters.Driven.Persistence.Repositories.InMemoryPostRepository

  ## Usage

      {:ok, updated_post} = ToggleLike.execute("post_1")
      {:error, :not_found} = ToggleLike.execute("invalid_id")
  """

  alias KlassHero.Community.Domain.Models.Post
  alias KlassHero.Community.Domain.Ports.ForManagingPosts
  alias KlassHero.Community.EventPublisher

  @doc """
  Executes the use case to toggle a like on a post.

  The function will:
  1. Retrieve the post from the repository
  2. Toggle the like status (add or remove)
  3. Update the post in the repository
  4. Return the updated post

  Parameters:
  - `post_id` - The unique identifier of the post to toggle like on

  Returns:
  - `{:ok, Post.t()}` - Updated post with toggled like status
  - `{:error, :not_found}` - Post not found
  - `{:error, :repository_unavailable}` - Repository not accessible
  - `{:error, :repository_error}` - General repository error

  ## Examples

      # Like a post (user_liked: false -> true, likes: 10 -> 11)
      {:ok, post} = ToggleLike.execute("post_1")
      assert post.user_liked == true
      assert post.likes == 11

      # Unlike a post (user_liked: true -> false, likes: 11 -> 10)
      {:ok, post} = ToggleLike.execute("post_1")
      assert post.user_liked == false
      assert post.likes == 10

      # Post not found
      {:error, :not_found} = ToggleLike.execute("invalid_id")
  """
  @spec execute(String.t()) ::
          {:ok, Post.t()}
          | {:error, :not_found | ForManagingPosts.get_error() | ForManagingPosts.update_error()}
  def execute(post_id) do
    with {:ok, post} <- repository_module().get_by_id(post_id),
         toggled_post = toggle_like_status(post),
         {:ok, updated_post} <- repository_module().update(toggled_post) do
      publish_like_event(updated_post)
      {:ok, updated_post}
    end
  end

  defp publish_like_event(%Post{user_liked: true} = post) do
    EventPublisher.publish_post_liked(post)
  end

  defp publish_like_event(%Post{user_liked: false} = post) do
    EventPublisher.publish_post_unliked(post)
  end

  defp toggle_like_status(%Post{user_liked: true} = post) do
    %{post | user_liked: false, likes: post.likes - 1}
  end

  defp toggle_like_status(%Post{user_liked: false} = post) do
    %{post | user_liked: true, likes: post.likes + 1}
  end

  defp repository_module do
    Application.get_env(:klass_hero, :community)[:repository]
  end
end
