defmodule PrimeYouth.Community.Adapters.Driven.Persistence.Repositories.InMemoryPostRepository do
  @moduledoc """
  In-memory repository for posts using Agent.

  This adapter implements the ForManagingPosts port using an Agent
  to store posts in memory. This implementation is suitable for:
  - Prototyping and early development
  - Testing without database dependencies
  - Demonstration and UI development

  ## Architecture

  The repository follows the Adapter pattern in Ports & Adapters architecture:
  - Implements the ForManagingPosts behavior
  - Uses Agent for thread-safe in-memory storage
  - Loads initial fixture data on startup
  - Provides proper error handling with rescue clauses

  ## Lifecycle

  The repository is started as part of the application supervision tree:

      children = [
        # ... other children
        PrimeYouth.Community.Adapters.Driven.Persistence.Repositories.InMemoryPostRepository,
        # ...
      ]

  ## Limitations

  - Data is not persisted across application restarts
  - All posts are kept in memory (not suitable for large datasets)
  - No query optimization or pagination
  - Single-process state (scales vertically only)
  """

  @behaviour PrimeYouth.Community.Domain.Ports.ForManagingPosts

  use Agent

  alias PrimeYouth.Community.Domain.Models.{Post, Comment}
  alias PrimeYouth.Community.Domain.Ports.ForManagingPosts
  alias PrimeYouthWeb.Theme

  @doc """
  Starts the in-memory post repository as a named Agent.

  Loads initial fixture data on startup to provide sample posts for
  the Community feed.

  ## Options

  - `opts` - Options passed to Agent.start_link (typically ignored)

  ## Returns

  - `{:ok, pid}` - Agent started successfully
  - `{:error, reason}` - Agent failed to start
  """
  def start_link(_opts) do
    Agent.start_link(fn -> load_initial_posts() end, name: __MODULE__)
  end

  @impl ForManagingPosts
  @doc """
  Lists all posts from the repository.

  Returns posts in the order they are stored (insertion order).

  ## Returns

  - `{:ok, [Post.t()]}` - List of all posts (may be empty)
  - `{:error, :repository_unavailable}` - Agent process not available
  """
  def list_all do
    posts = Agent.get(__MODULE__, & &1)
    {:ok, posts}
  rescue
    _ -> {:error, :repository_unavailable}
  end

  @impl ForManagingPosts
  @doc """
  Retrieves a post by its ID.

  ## Parameters

  - `post_id` - The unique identifier of the post

  ## Returns

  - `{:ok, Post.t()}` - The post with the given ID
  - `{:error, :not_found}` - No post with the given ID exists
  - `{:error, :repository_unavailable}` - Agent process not available
  """
  def get_by_id(post_id) do
    case Agent.get(__MODULE__, fn posts -> Enum.find(posts, &(&1.id == post_id)) end) do
      nil -> {:error, :not_found}
      post -> {:ok, post}
    end
  rescue
    _ -> {:error, :repository_unavailable}
  end

  @impl ForManagingPosts
  @doc """
  Updates an existing post in the repository.

  The post is identified by its ID and replaced with the provided post entity.

  ## Parameters

  - `post` - The updated post entity

  ## Returns

  - `{:ok, Post.t()}` - The updated post
  - `{:error, :not_found}` - No post with the given ID exists
  - `{:error, :repository_unavailable}` - Agent process not available
  """
  def update(%Post{} = post) do
    Agent.get_and_update(__MODULE__, fn posts ->
      case Enum.find_index(posts, &(&1.id == post.id)) do
        nil ->
          {{:error, :not_found}, posts}

        index ->
          updated_posts = List.replace_at(posts, index, post)
          {{:ok, post}, updated_posts}
      end
    end)
  rescue
    _ -> {:error, :repository_unavailable}
  end

  @doc """
  Resets the repository to its initial state.

  This function is useful for testing to ensure a clean state between tests.
  It reloads the initial fixture data, discarding any modifications.

  ## Returns

  - `:ok` - Repository reset successfully
  """
  def reset do
    Agent.update(__MODULE__, fn _posts -> load_initial_posts() end)
    :ok
  end

  # Private helper to load initial fixture data
  defp load_initial_posts do
    [
      %Post{
        id: "post_1",
        author: "Ms. Sarah - Art Instructor",
        avatar_bg: Theme.bg(:primary),
        avatar_emoji: "👩‍🏫",
        timestamp: "2 hours ago",
        content:
          "Amazing creativity from our Art World students today! 🎨 They're working on their masterpieces for the upcoming showcase. So proud of their progress!",
        type: :photo,
        photo_emoji: "🎨📸",
        likes: 12,
        comment_count: 2,
        user_liked: false,
        comments: [
          %Comment{author: "Parent Maria", text: "Emma loves this class!"},
          %Comment{author: "Parent John", text: "Can't wait for the showcase! 🎭"}
        ]
      },
      %Post{
        id: "post_2",
        author: "Mr. David - Chess Coach",
        avatar_bg: Theme.bg(:secondary),
        avatar_emoji: "👨‍🏫",
        timestamp: "5 hours ago",
        content:
          "Reminder: Chess tournament registration closes this Friday! 🏆 Great opportunity for our advanced students to showcase their skills. Prize ceremony will include medals and certificates! ♟️",
        type: :text,
        likes: 8,
        comment_count: 0,
        user_liked: false,
        comments: []
      },
      %Post{
        id: "post_3",
        author: "Prime Youth Admin",
        avatar_bg: Theme.bg(:accent),
        avatar_emoji: "📋",
        timestamp: "1 day ago",
        content:
          "🎉 Exciting News! We're hosting a Family Fun Day next Saturday! Join us for games, food trucks, and showcase performances from all our programs. Free entry for all Prime Youth families!",
        type: :event,
        event_details: %{
          title: "📅 Family Fun Day",
          date: "Saturday, March 15th • 10 AM - 4 PM",
          location: "Greenwood Elementary School"
        },
        likes: 25,
        comment_count: 0,
        user_liked: false,
        comments: []
      }
    ]
  end
end
