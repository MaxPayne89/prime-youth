defmodule PrimeYouth.Family.Adapters.Driven.Persistence.Repositories.InMemoryFamilyRepository do
  @moduledoc """
  In-memory repository implementation for family data using Elixir Agent.

  This repository provides a lightweight, in-memory storage solution for
  family data during development and testing. It initializes with sample
  data from fixtures and maintains state in an Agent process.

  ## Architecture

  This follows the Adapter pattern in DDD/Ports & Adapters:
  - Implements the ForManagingFamily port
  - Uses Agent for state management
  - Initializes from fixture data
  - Provides reset functionality for testing

  ## Supervision

  This repository runs as a supervised Agent process and must be added
  to the application supervision tree:

      children = [
        {PrimeYouth.Family.Adapters.Driven.Persistence.Repositories.InMemoryFamilyRepository, []}
      ]

  ## Testing

  Use `reset/0` to restore initial fixture data during testing:

      setup do
        InMemoryFamilyRepository.reset()
        :ok
      end
  """

  @behaviour PrimeYouth.Family.Domain.Ports.ForManagingFamily

  use Agent

  alias PrimeYouth.Family.Domain.Models.{User, Child}
  alias PrimeYouthWeb.Live.SampleFixtures

  @doc """
  Starts the in-memory family repository Agent.

  Initializes the repository with sample data from fixtures.
  This function is called automatically by the supervisor.
  """
  def start_link(_opts) do
    Agent.start_link(&load_initial_data/0, name: __MODULE__)
  end

  @impl true
  @doc """
  Retrieves the current user.

  Returns the logged-in user's information from in-memory storage.

  Returns:
  - `{:ok, User.t()}` - Current user
  - `{:error, :not_found}` - No user available (should not happen in normal operation)
  """
  @spec get_current_user() :: {:ok, User.t()} | {:error, :not_found}
  def get_current_user do
    user = Agent.get(__MODULE__, fn state -> state.user end)

    if user do
      {:ok, user}
    else
      {:error, :not_found}
    end
  end

  @impl true
  @doc """
  Lists children for the current user.

  Returns children in either simple or extended format.

  Returns:
  - `{:ok, [Child.t()]}` - List of children (may be empty)

  ## Examples

      {:ok, children} = list_children(:simple)
      {:ok, children} = list_children(:extended)
  """
  @spec list_children(:simple | :extended) :: {:ok, [Child.t()]}
  def list_children(variant \\ :extended) do
    children =
      Agent.get(__MODULE__, fn state ->
        case variant do
          :simple -> state.children_simple
          :extended -> state.children_extended
        end
      end)

    {:ok, children}
  end

  @doc """
  Resets the repository to its initial state.

  This is useful for testing to ensure a clean state between tests.
  Reloads all data from fixtures.

  ## Examples

      InMemoryFamilyRepository.reset()
  """
  def reset do
    Agent.update(__MODULE__, fn _state -> load_initial_data() end)
  end

  # Private Functions

  defp load_initial_data do
    # Load user from fixtures
    fixture_user = SampleFixtures.sample_user()

    # Note: SampleFixtures.sample_user() doesn't have an id field,
    # so we use a hardcoded ID of 1 for the single user
    user = %User{
      id: 1,
      name: fixture_user.name,
      email: fixture_user.email,
      avatar: fixture_user.avatar,
      children_summary: fixture_user.children_summary
    }

    # Load simple children from fixtures
    fixture_children_simple = SampleFixtures.sample_children(:simple)

    children_simple =
      Enum.map(fixture_children_simple, fn child ->
        %Child{
          id: child.id,
          name: child.name,
          age: child.age,
          school: nil,
          sessions: nil,
          progress: nil,
          activities: nil
        }
      end)

    # Load extended children from fixtures
    fixture_children_extended = SampleFixtures.sample_children(:extended)

    children_extended =
      Enum.map(fixture_children_extended, fn child ->
        %Child{
          id: child.id,
          name: child.name,
          age: child.age,
          school: child.school,
          sessions: child.sessions,
          progress: child.progress,
          activities: child.activities
        }
      end)

    %{
      user: user,
      children_simple: children_simple,
      children_extended: children_extended
    }
  end
end
