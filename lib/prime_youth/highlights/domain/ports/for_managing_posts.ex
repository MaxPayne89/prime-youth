defmodule PrimeYouth.Highlights.Domain.Ports.ForManagingPosts do
  @moduledoc """
  Port for managing posts in the Highlights context.

  This port defines the contract that any persistence adapter must implement
  to provide post management capabilities. The port follows the Hexagonal
  Architecture pattern, allowing the domain layer to remain independent of
  specific infrastructure implementations.

  ## Repository Operations

  - `list_all/0` - Retrieve all posts from the repository
  - `get_by_id/1` - Retrieve a specific post by its ID
  - `update/1` - Update an existing post in the repository

  ## Error Handling

  All operations return `{:ok, result}` tuples on success or `{:error, reason}`
  tuples on failure. Error reasons are defined as types for compile-time checking.
  """

  alias PrimeYouth.Highlights.Domain.Models.Post

  @type list_error :: :repository_unavailable | :repository_error
  @type get_error :: :not_found | :repository_unavailable | :repository_error
  @type update_error :: :not_found | :repository_unavailable | :repository_error

  @doc """
  Lists all posts.

  Returns:
  - `{:ok, [Post.t()]}` - List of all posts (may be empty)
  - `{:error, :repository_unavailable}` - Repository not accessible
  - `{:error, :repository_error}` - General repository error
  """
  @callback list_all() :: {:ok, [Post.t()]} | {:error, list_error()}

  @doc """
  Retrieves a post by ID.

  Parameters:
  - `post_id` - The unique identifier of the post

  Returns:
  - `{:ok, Post.t()}` - The post
  - `{:error, :not_found}` - Post not found
  - `{:error, :repository_unavailable}` - Repository not accessible
  - `{:error, :repository_error}` - General repository error
  """
  @callback get_by_id(String.t()) :: {:ok, Post.t()} | {:error, get_error()}

  @doc """
  Updates an existing post.

  The post must exist in the repository. This operation replaces the entire
  post entity with the provided one.

  Parameters:
  - `post` - The post entity with updated data

  Returns:
  - `{:ok, Post.t()}` - Updated post
  - `{:error, :not_found}` - Post not found
  - `{:error, :repository_unavailable}` - Repository not accessible
  - `{:error, :repository_error}` - General repository error
  """
  @callback update(Post.t()) :: {:ok, Post.t()} | {:error, update_error()}
end
