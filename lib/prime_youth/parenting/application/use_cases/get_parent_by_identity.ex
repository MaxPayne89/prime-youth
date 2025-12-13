defmodule PrimeYouth.Parenting.Application.UseCases.GetParentByIdentity do
  @moduledoc """
  Use case for retrieving a parent profile by identity ID from the Parenting context.

  This use case orchestrates the retrieval of a parent profile using the identity_id
  correlation to the Accounts context.

  ## Architecture

  This use case follows the Application Layer pattern in DDD/Ports & Adapters:
  - Coordinates domain operations (via repository port)
  - No business logic (that belongs in domain layer)
  - No logging (that belongs in adapter layer)
  - Returns domain entities (Parent structs)

  ## Dependency Injection

  The repository implementation is configured via Application config:

      config :prime_youth, :parenting,
        repository: PrimeYouth.Parenting.Adapters.Driven.Persistence.Repositories.ParentRepository

  ## Usage

      {:ok, parent} = GetParentByIdentity.execute("550e8400-...")
      {:error, :not_found} = GetParentByIdentity.execute("non-existent-id")
  """

  alias PrimeYouth.Parenting.Domain.Models.Parent
  alias PrimeYouth.Parenting.Domain.Ports.ForStoringParents

  @doc """
  Executes the use case to retrieve a parent profile by identity ID.

  Retrieves the parent profile associated with the given identity_id if it exists.

  Returns:
  - `{:ok, Parent.t()}` - Parent profile found
  - `{:error, :not_found}` - No parent profile exists for this identity_id
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      # Successful retrieval
      {:ok, parent} = GetParentByIdentity.execute("550e8400-e29b-41d4-a716-446655440001")
      IO.puts(parent.display_name)

      # Parent profile not found
      {:error, :not_found} = GetParentByIdentity.execute("550e8400-e29b-41d4-a716-446655440099")

      # Database errors
      {:error, :database_connection_error} = GetParentByIdentity.execute("invalid-uuid")
  """
  @spec execute(String.t()) ::
          {:ok, Parent.t()} | {:error, :not_found | ForStoringParents.storage_error()}
  def execute(identity_id) when is_binary(identity_id) do
    repository_module().get_by_identity_id(identity_id)
  end

  # Private helper to get the configured repository module
  defp repository_module do
    Application.get_env(:prime_youth, :parenting)[:repository]
  end
end
