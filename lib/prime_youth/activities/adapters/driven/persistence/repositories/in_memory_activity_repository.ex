defmodule PrimeYouth.Activities.Adapters.Driven.Persistence.Repositories.InMemoryActivityRepository do
  @moduledoc """
  In-memory repository implementation for activities using Elixir Agent.

  This repository provides a lightweight, in-memory storage solution for
  activities during development and testing. It initializes with sample
  data from fixtures and maintains state in an Agent process.

  ## Architecture

  This follows the Adapter pattern in DDD/Ports & Adapters:
  - Implements the ForManagingActivities port
  - Uses Agent for state management
  - Initializes from fixture data
  - Provides reset functionality for testing

  ## Supervision

  This repository runs as a supervised Agent process and must be added
  to the application supervision tree:

      children = [
        {PrimeYouth.Activities.Adapters.Driven.Persistence.Repositories.InMemoryActivityRepository, []}
      ]

  ## Testing

  Use `reset/0` to restore initial fixture data during testing:

      setup do
        InMemoryActivityRepository.reset()
        :ok
      end
  """

  @behaviour PrimeYouth.Activities.Domain.Ports.ForManagingActivities

  use Agent

  alias PrimeYouth.Activities.Domain.Models.Activity
  alias PrimeYouthWeb.Live.SampleFixtures

  @doc """
  Starts the in-memory activity repository Agent.

  Initializes the repository with sample data from fixtures.
  This function is called automatically by the supervisor.
  """
  def start_link(_opts) do
    Agent.start_link(&load_initial_data/0, name: __MODULE__)
  end

  @impl true
  @doc """
  Lists upcoming activities.

  Returns all scheduled upcoming activities from in-memory storage.

  Returns:
  - `{:ok, [Activity.t()]}` - List of upcoming activities (may be empty)

  ## Examples

      {:ok, activities} = list_upcoming()
      length(activities) > 0  # => true
  """
  def list_upcoming do
    activities = Agent.get(__MODULE__, fn state -> state.activities end)
    {:ok, activities}
  end

  @doc """
  Resets the repository to its initial state.

  This is useful for testing to ensure a clean state between tests.
  Reloads all data from fixtures.

  ## Examples

      InMemoryActivityRepository.reset()
  """
  def reset do
    Agent.update(__MODULE__, fn _state -> load_initial_data() end)
  end

  defp load_initial_data do
    fixture_activities = SampleFixtures.sample_upcoming_activities()

    activities =
      Enum.map(fixture_activities, fn activity ->
        %Activity{
          id: activity.id,
          status: activity.status,
          status_color: activity.status_color,
          time: activity.time,
          name: activity.name,
          instructor: activity.instructor
        }
      end)

    %{activities: activities}
  end
end
