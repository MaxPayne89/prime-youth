defmodule KlassHero.Community.Application.UseCases.AddComment do
  @moduledoc """
  Use case for adding a comment to a post.

  This use case implements the business logic for adding comments:
  - Create a new comment with the provided author and text
  - Append the comment to the post's comments list
  - Increment the post's comment count
  - Update the post in the repository

  ## Architecture

  This use case follows the Application Layer pattern in DDD/Ports & Adapters:
  - Contains business logic for comment addition
  - Coordinates repository operations (get, update)
  - Returns domain entities (Post structs)

  ## Dependency Injection

  The repository implementation is configured via Application config:

      config :klass_hero, :community,
        repository: KlassHero.Community.Adapters.Driven.Persistence.Repositories.InMemoryPostRepository

  ## Usage

      {:ok, updated_post} = AddComment.execute("post_1", "Great post!", "John Doe")
      {:error, :not_found} = AddComment.execute("invalid_id", "Comment", "User")
  """

  alias KlassHero.Community.Domain.Events.CommunityEvents
  alias KlassHero.Community.Domain.Models.{Comment, Post}
  alias KlassHero.Community.Domain.Ports.ForManagingPosts
  alias KlassHero.Shared.DomainEventBus

  @context KlassHero.Community

  @doc """
  Executes the use case to add a comment to a post.

  The function will:
  1. Retrieve the post from the repository
  2. Create a new comment with the provided text and author
  3. Append the comment to the post's comments list
  4. Increment the comment count
  5. Update the post in the repository
  6. Return the updated post

  Parameters:
  - `post_id` - The unique identifier of the post to add a comment to
  - `comment_text` - The text content of the comment
  - `author` - The name of the comment author

  Returns:
  - `{:ok, Post.t()}` - Updated post with the new comment
  - `{:error, :not_found}` - Post not found
  - `{:error, :repository_unavailable}` - Repository not accessible
  - `{:error, :repository_error}` - General repository error

  ## Examples

      # Add a comment to a post
      {:ok, post} = AddComment.execute("post_1", "Great content!", "John Doe")
      assert length(post.comments) == 3
      assert post.comment_count == 3
      assert List.last(post.comments).text == "Great content!"
      assert List.last(post.comments).author == "John Doe"

      # Post not found
      {:error, :not_found} = AddComment.execute("invalid_id", "Comment", "User")
  """
  @spec execute(String.t(), String.t(), String.t()) ::
          {:ok, Post.t()}
          | {:error, :not_found | ForManagingPosts.get_error() | ForManagingPosts.update_error()}
  def execute(post_id, comment_text, author) do
    with {:ok, post} <- repository_module().get_by_id(post_id),
         post_with_comment = add_comment_to_post(post, comment_text, author),
         {:ok, updated_post} <- repository_module().update(post_with_comment) do
      DomainEventBus.dispatch(
        @context,
        CommunityEvents.comment_added(updated_post, author, comment_text)
      )
      {:ok, updated_post}
    end
  end

  defp add_comment_to_post(post, comment_text, author) do
    new_comment = %Comment{author: author, text: comment_text}

    %{
      post
      | comments: post.comments ++ [new_comment],
        comment_count: post.comment_count + 1
    }
  end

  defp repository_module do
    Application.get_env(:klass_hero, :community)[:repository]
  end
end
