defmodule PrimeYouth.Family.Application.UseCases.GetCurrentUser do
  @moduledoc """
  Use case for retrieving the current user from the Family context.

  This use case orchestrates the retrieval of the logged-in user's information
  from the repository. It delegates to the repository port and returns the result
  without additional processing.

  ## Architecture

  This use case follows the Application Layer pattern in DDD/Ports & Adapters:
  - Coordinates domain operations (via repository port)
  - No business logic (that belongs in domain layer)
  - No logging (that belongs in adapter layer)
  - Returns domain entities (User structs)

  ## Dependency Injection

  The repository implementation is configured via Application config:

      config :prime_youth, :family,
        repository: PrimeYouth.Family.Adapters.Driven.Persistence.Repositories.InMemoryFamilyRepository

  ## Usage

      {:ok, user} = GetCurrentUser.execute()
      IO.puts(user.name)

      {:error, :not_found} = GetCurrentUser.execute()
  """

  alias PrimeYouth.Family.Domain.Models.User

  @doc """
  Executes the use case to retrieve the current user.

  Retrieves the logged-in user's information from the repository.
  In the current implementation, this returns fixture data for development purposes.

  Returns:
  - `{:ok, User.t()}` - Current user found
  - `{:error, :not_found}` - No current user available

  ## Examples

      # Successful retrieval
      {:ok, user} = GetCurrentUser.execute()
      user.name  # => "Sarah Johnson"

      # No user found
      {:error, :not_found} = GetCurrentUser.execute()
  """
  @spec execute() :: {:ok, User.t()} | {:error, :not_found}
  def execute do
    repository_module().get_current_user()
  end

  defp repository_module do
    Application.get_env(:prime_youth, :family)[:repository]
  end
end
