defmodule PrimeYouth.Parenting.Application.UseCases.CreateParentProfile do
  @moduledoc """
  Use case for creating a new parent profile in the Parenting context.

  This use case orchestrates the creation of a parent profile from identity information.
  It delegates to the repository port and returns the created parent entity.

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

      {:ok, parent} = CreateParentProfile.execute(%{identity_id: "550e8400-..."})
      {:error, :duplicate_identity} = CreateParentProfile.execute(%{identity_id: "existing-id"})
  """

  alias PrimeYouth.Parenting.Domain.Models.Parent
  alias PrimeYouth.Parenting.Domain.Ports.ForStoringParents

  @doc """
  Executes the use case to create a new parent profile.

  Creates a new parent profile associated with the given identity_id.
  All fields except identity_id are optional and can be provided in the attrs map.

  Returns:
  - `{:ok, Parent.t()}` - Parent profile created successfully
  - `{:error, :duplicate_identity}` - Parent profile already exists for this identity_id
  - `{:error, :invalid_identity}` - Identity ID does not exist
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      # Create with just identity_id (minimal)
      {:ok, parent} = CreateParentProfile.execute(%{
        identity_id: "550e8400-e29b-41d4-a716-446655440001"
      })

      # Create with full profile information
      {:ok, parent} = CreateParentProfile.execute(%{
        identity_id: "550e8400-e29b-41d4-a716-446655440001",
        display_name: "John Doe",
        phone: "+1234567890",
        location: "New York, NY",
        notification_preferences: %{email: true, sms: false}
      })

      # Duplicate identity error
      {:error, :duplicate_identity} = CreateParentProfile.execute(%{
        identity_id: "existing-id"
      })
  """
  @spec execute(map()) :: {:ok, Parent.t()} | {:error, ForStoringParents.storage_error()}
  def execute(attrs) when is_map(attrs) do
    repository_module().create_parent_profile(attrs)
  end

  # Private helper to get the configured repository module
  defp repository_module do
    Application.get_env(:prime_youth, :parenting)[:repository]
  end
end
