defmodule PrimeYouth.Activities.Application.UseCases.ListUpcomingActivities do
  @moduledoc """
  Use case for listing upcoming activities from the Activities context.

  This use case orchestrates the retrieval of scheduled upcoming activities
  from the repository. It delegates to the repository port and returns the result
  without additional processing.

  ## Architecture

  This use case follows the Application Layer pattern in DDD/Ports & Adapters:
  - Coordinates domain operations (via repository port)
  - No business logic (that belongs in domain layer)
  - No logging (that belongs in adapter layer)
  - Returns domain entities (Activity structs)

  ## Dependency Injection

  The repository implementation is configured via Application config:

      config :prime_youth, :activities,
        repository: PrimeYouth.Activities.Adapters.Driven.Persistence.Repositories.InMemoryActivityRepository

  ## Usage

      {:ok, activities} = ListUpcomingActivities.execute()
      length(activities) > 0  # => true

      {:ok, []} = ListUpcomingActivities.execute()  # No activities
  """

  alias PrimeYouth.Activities.Domain.Models.Activity

  @doc """
  Executes the use case to list upcoming activities.

  Retrieves all scheduled upcoming activities from the repository.
  In the current implementation, this returns fixture data for development purposes.

  Returns:
  - `{:ok, [Activity.t()]}` - List of upcoming activities (may be empty)

  ## Examples

      # Successful retrieval with activities
      {:ok, activities} = ListUpcomingActivities.execute()
      length(activities) > 0  # => true

      # Empty list
      {:ok, []} = ListUpcomingActivities.execute()
  """
  @spec execute() :: {:ok, [Activity.t()]}
  def execute do
    repository_module().list_upcoming()
  end

  # Private helper to get the configured repository module
  defp repository_module do
    Application.get_env(:prime_youth, :activities)[:repository]
  end
end
