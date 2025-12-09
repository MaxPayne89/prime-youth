defmodule PrimeYouth.Activities.Domain.Ports.ForManagingActivities do
  @moduledoc """
  Repository port for managing activities in the Activities bounded context.

  This is a behaviour (interface) that defines the contract for activity data access.
  It is implemented by adapters in the infrastructure layer (e.g., in-memory repositories).

  This port follows the Ports & Adapters architecture pattern, keeping the domain
  layer independent of infrastructure concerns.

  ## Implementations

  Current implementations:
  - `PrimeYouth.Activities.Adapters.Driven.Persistence.Repositories.InMemoryActivityRepository`
    Agent-based in-memory storage for development and testing

  Future implementations could include:
  - Database-backed repository using Ecto
  - External API integration for activity scheduling
  """

  alias PrimeYouth.Activities.Domain.Models.Activity

  @doc """
  Lists upcoming activities.

  Returns all scheduled upcoming activities for the current user.
  In the current implementation, this returns fixture data for development purposes.

  Returns:
  - `{:ok, [Activity.t()]}` - List of upcoming activities (may be empty)

  ## Examples

      {:ok, activities} = list_upcoming()
      length(activities) > 0  # => true

      {:ok, []} = list_upcoming()  # No activities scheduled
  """
  @callback list_upcoming() :: {:ok, [Activity.t()]}
end
