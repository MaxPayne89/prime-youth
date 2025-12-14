defmodule PrimeYouth.Providing do
  @moduledoc """
  Public API for the Providing bounded context.

  This module provides the public interface for provider profile management,
  delegating to use cases in the application layer.

  ## Usage

      # Create a provider profile
      {:ok, provider} = Providing.create_provider_profile(%{
        identity_id: "550e8400-e29b-41d4-a716-446655440001",
        business_name: "Kids Sports Academy",
        description: "Premier youth sports training"
      })

      # Retrieve a provider profile by identity ID
      {:ok, provider} = Providing.get_provider_by_identity("550e8400-...")

      # Check if a provider profile exists
      {:ok, true} = Providing.has_profile?("550e8400-...")

  ## Architecture

  This context follows the Ports & Adapters architecture:
  - Public API (this module) → delegates to use cases
  - Use cases (application layer) → orchestrate domain operations
  - Repository port (domain layer) → defines persistence contract
  - Repository implementation (adapter layer) → implements persistence

  ## Configuration

  The repository implementation is configured in config/config.exs:

      config :prime_youth, :providing,
        repository: PrimeYouth.Providing.Adapters.Driven.Persistence.Repositories.ProviderRepository
  """

  alias PrimeYouth.Providing.Application.UseCases.CreateProviderProfile
  alias PrimeYouth.Providing.Application.UseCases.GetProviderByIdentity
  alias PrimeYouth.Providing.Domain.Models.Provider

  @doc """
  Creates a new provider profile.

  Accepts a map with provider attributes. The identity_id and business_name are required.
  All other fields are optional.

  Returns:
  - `{:ok, Provider.t()}` - Provider profile created successfully
  - `{:error, :duplicate_identity}` - Provider profile already exists for this identity_id
  - `{:error, :invalid_identity}` - Identity ID does not exist
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      # Create with minimal information
      {:ok, provider} = Providing.create_provider_profile(%{
        identity_id: "550e8400-e29b-41d4-a716-446655440001",
        business_name: "My Business"
      })

      # Create with full profile
      {:ok, provider} = Providing.create_provider_profile(%{
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

      # Duplicate identity error
      {:error, :duplicate_identity} = Providing.create_provider_profile(%{
        identity_id: "existing-id",
        business_name: "Another Business"
      })
  """
  @spec create_provider_profile(map()) ::
          {:ok, Provider.t()}
          | {:error,
             :duplicate_identity
             | :invalid_identity
             | :database_connection_error
             | :database_query_error
             | :database_unavailable}
  def create_provider_profile(attrs) when is_map(attrs) do
    CreateProviderProfile.execute(attrs)
  end

  @doc """
  Retrieves a provider profile by identity ID.

  Returns the provider profile associated with the given identity_id if found.

  Returns:
  - `{:ok, Provider.t()}` - Provider profile found
  - `{:error, :not_found}` - No provider profile exists for this identity_id
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      # Successful retrieval
      {:ok, provider} = Providing.get_provider_by_identity("550e8400-e29b-41d4-a716-446655440001")
      IO.puts(provider.business_name)

      # Provider profile not found
      {:error, :not_found} = Providing.get_provider_by_identity("non-existent-id")
  """
  @spec get_provider_by_identity(String.t()) ::
          {:ok, Provider.t()}
          | {:error,
             :not_found
             | :database_connection_error
             | :database_query_error
             | :database_unavailable}
  def get_provider_by_identity(identity_id) when is_binary(identity_id) do
    GetProviderByIdentity.execute(identity_id)
  end

  @doc """
  Checks if a provider profile exists for the given identity ID.

  Returns boolean indicating whether a provider profile exists.

  Returns:
  - `{:ok, true}` - Provider profile exists
  - `{:ok, false}` - No provider profile exists
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      {:ok, true} = Providing.has_profile?("550e8400-e29b-41d4-a716-446655440001")
      {:ok, false} = Providing.has_profile?("non-existent-id")
  """
  @spec has_profile?(String.t()) ::
          {:ok, boolean()}
          | {:error, :database_connection_error | :database_query_error | :database_unavailable}
  def has_profile?(identity_id) when is_binary(identity_id) do
    repository_module = Application.get_env(:prime_youth, :providing)[:repository]
    repository_module.has_profile?(identity_id)
  end
end
