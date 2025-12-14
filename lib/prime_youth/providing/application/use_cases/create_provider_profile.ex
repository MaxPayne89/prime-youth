defmodule PrimeYouth.Providing.Application.UseCases.CreateProviderProfile do
  @moduledoc """
  Use case for creating a new provider profile in the Providing context.

  This use case orchestrates the creation of a provider profile from identity information.
  It delegates to the repository port and returns the created provider entity.

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

      {:ok, provider} = CreateProviderProfile.execute(%{identity_id: "550e8400-...", business_name: "My Business"})
      {:error, :duplicate_identity} = CreateProviderProfile.execute(%{identity_id: "existing-id", business_name: "Another"})
  """

  alias PrimeYouth.Providing.Domain.Models.Provider
  alias PrimeYouth.Providing.Domain.Ports.ForStoringProviders

  @doc """
  Executes the use case to create a new provider profile.

  Creates a new provider profile associated with the given identity_id.
  Both identity_id and business_name are required. All other fields are optional.

  Domain validation runs before persistence for fail-fast behavior.

  Returns:
  - `{:ok, Provider.t()}` - Provider profile created successfully
  - `{:error, {:validation_error, [String.t()]}}` - Domain validation failed
  - `{:error, :duplicate_identity}` - Provider profile already exists for this identity_id
  - `{:error, :invalid_identity}` - Identity ID does not exist
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      # Create with minimal required fields
      {:ok, provider} = CreateProviderProfile.execute(%{
        identity_id: "550e8400-e29b-41d4-a716-446655440001",
        business_name: "My Business"
      })

      # Create with full profile information
      {:ok, provider} = CreateProviderProfile.execute(%{
        identity_id: "550e8400-e29b-41d4-a716-446655440001",
        business_name: "Kids Sports Academy",
        description: "Premier youth sports training",
        phone: "+1234567890",
        website: "https://kidssports.example.com",
        address: "123 Sports Lane",
        logo_url: "https://kidssports.example.com/logo.png",
        verified: false,
        categories: ["sports", "outdoor"]
      })

      # Domain validation error
      {:error, {:validation_error, ["Business name cannot be empty"]}} =
        CreateProviderProfile.execute(%{
          identity_id: "550e8400-e29b-41d4-a716-446655440001",
          business_name: ""
        })

      # Duplicate identity error
      {:error, :duplicate_identity} = CreateProviderProfile.execute(%{
        identity_id: "existing-id",
        business_name: "Another Business"
      })
  """
  @spec execute(map()) :: {:ok, Provider.t()} | {:error, ForStoringProviders.storage_error()}
  def execute(attrs) when is_map(attrs) do
    # Auto-generate UUID if not provided for domain validation
    attrs_with_id = Map.put_new(attrs, :id, Ecto.UUID.generate())

    with {:ok, _validated_provider} <- Provider.new(attrs_with_id),
         {:ok, persisted_provider} <- repository_module().create_provider_profile(attrs_with_id) do
      {:ok, persisted_provider}
    else
      {:error, validation_errors} when is_list(validation_errors) ->
        {:error, {:validation_error, validation_errors}}

      {:error, _storage_error} = error ->
        error
    end
  end

  # Private helper to get the configured repository module
  defp repository_module do
    Application.get_env(:prime_youth, :providing)[:repository]
  end
end
