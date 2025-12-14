defmodule PrimeYouth.Parenting do
  @moduledoc """
  Public API for the Parenting bounded context.

  This module provides the public interface for parent profile management,
  delegating to use cases in the application layer.

  ## Usage

      # Create a parent profile
      {:ok, parent} = Parenting.create_parent_profile(%{
        identity_id: "550e8400-e29b-41d4-a716-446655440001",
        display_name: "John Doe",
        phone: "+1234567890"
      })

      # Retrieve a parent profile by identity ID
      {:ok, parent} = Parenting.get_parent_by_identity("550e8400-...")

      # Check if a parent profile exists
      {:ok, true} = Parenting.has_profile?("550e8400-...")

  ## Architecture

  This context follows the Ports & Adapters architecture:
  - Public API (this module) → delegates to use cases
  - Use cases (application layer) → orchestrate domain operations
  - Repository port (domain layer) → defines persistence contract
  - Repository implementation (adapter layer) → implements persistence

  ## Configuration

  The repository implementation is configured in config/config.exs:

      config :prime_youth, :parenting,
        repository: PrimeYouth.Parenting.Adapters.Driven.Persistence.Repositories.ParentRepository
  """

  alias PrimeYouth.Parenting.Application.UseCases.CreateParentProfile
  alias PrimeYouth.Parenting.Application.UseCases.GetParentByIdentity
  alias PrimeYouth.Parenting.Domain.Models.Parent

  @doc """
  Creates a new parent profile.

  Accepts a map with parent attributes. The identity_id is required.
  All other fields (display_name, phone, location, notification_preferences) are optional.

  Returns:
  - `{:ok, Parent.t()}` - Parent profile created successfully
  - `{:error, :duplicate_identity}` - Parent profile already exists for this identity_id
  - `{:error, :invalid_identity}` - Identity ID does not exist
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      # Create with minimal information
      {:ok, parent} = Parenting.create_parent_profile(%{
        identity_id: "550e8400-e29b-41d4-a716-446655440001"
      })

      # Create with full profile
      {:ok, parent} = Parenting.create_parent_profile(%{
        identity_id: "550e8400-e29b-41d4-a716-446655440001",
        display_name: "John Doe",
        phone: "+1234567890",
        location: "New York, NY",
        notification_preferences: %{email: true, sms: false}
      })

      # Duplicate identity error
      {:error, :duplicate_identity} = Parenting.create_parent_profile(%{
        identity_id: "existing-id"
      })
  """
  @spec create_parent_profile(map()) ::
          {:ok, Parent.t()}
          | {:error,
             :duplicate_identity
             | :invalid_identity
             | :database_connection_error
             | :database_query_error
             | :database_unavailable}
  def create_parent_profile(attrs) when is_map(attrs) do
    CreateParentProfile.execute(attrs)
  end

  @doc """
  Retrieves a parent profile by identity ID.

  Returns the parent profile associated with the given identity_id if found.

  Returns:
  - `{:ok, Parent.t()}` - Parent profile found
  - `{:error, :not_found}` - No parent profile exists for this identity_id
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      # Successful retrieval
      {:ok, parent} = Parenting.get_parent_by_identity("550e8400-e29b-41d4-a716-446655440001")
      IO.puts(parent.display_name)

      # Parent profile not found
      {:error, :not_found} = Parenting.get_parent_by_identity("non-existent-id")
  """
  @spec get_parent_by_identity(String.t()) ::
          {:ok, Parent.t()}
          | {:error,
             :not_found
             | :database_connection_error
             | :database_query_error
             | :database_unavailable}
  def get_parent_by_identity(identity_id) when is_binary(identity_id) do
    GetParentByIdentity.execute(identity_id)
  end

  @doc """
  Checks if a parent profile exists for the given identity ID.

  Returns boolean indicating whether a parent profile exists.

  Returns:
  - `{:ok, true}` - Parent profile exists
  - `{:ok, false}` - No parent profile exists
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      {:ok, true} = Parenting.has_profile?("550e8400-e29b-41d4-a716-446655440001")
      {:ok, false} = Parenting.has_profile?("non-existent-id")
  """
  @spec has_profile?(String.t()) ::
          {:ok, boolean()}
          | {:error, :database_connection_error | :database_query_error | :database_unavailable}
  def has_profile?(identity_id) when is_binary(identity_id) do
    repository_module = Application.get_env(:prime_youth, :parenting)[:repository]
    repository_module.has_profile?(identity_id)
  end
end
