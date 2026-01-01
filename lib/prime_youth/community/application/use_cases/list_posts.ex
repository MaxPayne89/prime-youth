defmodule PrimeYouth.Community.Application.UseCases.ListPosts do
  @moduledoc """
  Use case for listing all posts in the Community feed.

  This use case orchestrates the retrieval of all posts from the repository.
  It delegates to the repository port and returns the result without additional processing.

  ## Architecture

  This use case follows the Application Layer pattern in DDD/Ports & Adapters:
  - Coordinates domain operations (via repository port)
  - No business logic (that belongs in domain layer)
  - No logging (that belongs in adapter layer)
  - Returns domain entities (Post structs)

  ## Dependency Injection

  The repository implementation is configured via Application config:

      config :prime_youth, :community,
        repository: PrimeYouth.Community.Adapters.Driven.Persistence.Repositories.InMemoryPostRepository

  ## Usage

      {:ok, posts} = ListPosts.execute()
      {:error, :repository_unavailable} = ListPosts.execute()
      {:error, :repository_error} = ListPosts.execute()
  """

  alias PrimeYouth.Community.Domain.Models.Post
  alias PrimeYouth.Community.Domain.Ports.ForManagingPosts

  @doc """
  Executes the use case to list all posts in the Community feed.

  Retrieves all posts from the repository. Posts are returned in the order
  maintained by the repository implementation.

  Returns:
  - `{:ok, [Post.t()]}` - List of posts (may be empty)
  - `{:error, :repository_unavailable}` - Repository not accessible
  - `{:error, :repository_error}` - General repository error

  ## Examples

      # Successful retrieval
      {:ok, posts} = ListPosts.execute()
      Enum.each(posts, fn post ->
        IO.puts(post.author)
      end)

      # Empty feed
      {:ok, []} = ListPosts.execute()

      # Repository errors
      {:error, :repository_unavailable} = ListPosts.execute()
      {:error, :repository_error} = ListPosts.execute()
  """
  @spec execute() :: {:ok, [Post.t()]} | {:error, ForManagingPosts.list_error()}
  def execute do
    repository_module().list_all()
  end

  defp repository_module do
    Application.get_env(:prime_youth, :community)[:repository]
  end
end
