defmodule PrimeYouth.Providing.Application.UseCases.GetProviderByIdentity do
  @moduledoc """
  Use case for retrieving a provider profile by identity ID from the Providing context.

  This use case orchestrates the retrieval of a provider profile using the identity_id
  correlation to the Accounts context.

  ## Architecture

  This use case follows the Application Layer pattern in DDD/Ports & Adapters:
  - Coordinates domain operations (via repository port)
  - No business logic (that belongs in domain layer)
  - No logging (that belongs in adapter layer)
  - Returns domain entities (Provider structs)

  ## Dependency Injection

  The repository implementation is configured via Application config:

      config :prime_youth, :providing,
        repository: PrimeYouth.Providing.Adapters.Driven.Persistence.Repositories.ProviderRepository

  ## Usage

      {:ok, provider} = GetProviderByIdentity.execute("550e8400-...")
      {:error, :not_found} = GetProviderByIdentity.execute("non-existent-id")
  """

  alias PrimeYouth.Providing.Domain.Models.Provider
  alias PrimeYouth.Providing.Domain.Ports.ForStoringProviders

  @doc """
  Executes the use case to retrieve a provider profile by identity ID.

  Retrieves the provider profile associated with the given identity_id if it exists.

  Returns:
  - `{:ok, Provider.t()}` - Provider profile found
  - `{:error, :not_found}` - No provider profile exists for this identity_id
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      # Successful retrieval
      {:ok, provider} = GetProviderByIdentity.execute("550e8400-e29b-41d4-a716-446655440001")
      IO.puts(provider.business_name)

      # Provider profile not found
      {:error, :not_found} = GetProviderByIdentity.execute("550e8400-e29b-41d4-a716-446655440099")

      # Database errors
      {:error, :database_connection_error} = GetProviderByIdentity.execute("invalid-uuid")
  """
  @spec execute(String.t()) ::
          {:ok, Provider.t()} | {:error, :not_found | ForStoringProviders.storage_error()}
  def execute(identity_id) when is_binary(identity_id) do
    repository_module().get_by_identity_id(identity_id)
  end

  # Private helper to get the configured repository module
  defp repository_module do
    Application.get_env(:prime_youth, :providing)[:repository]
  end
end
