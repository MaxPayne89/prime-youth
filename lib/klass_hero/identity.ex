defmodule KlassHero.Identity do
  @moduledoc """
  Public API for the Identity bounded context.

  This module provides the public interface for managing user identities
  including parent profiles, provider profiles, and children. It consolidates
  identity-related functionality previously spread across Parenting, Providing,
  and Family contexts.

  ## Usage

      # Parent Profiles
      {:ok, parent} = Identity.create_parent_profile(%{identity_id: "user-uuid"})
      {:ok, parent} = Identity.get_parent_by_identity("user-uuid")
      true = Identity.has_parent_profile?("user-uuid")

      # Provider Profiles
      {:ok, provider} = Identity.create_provider_profile(%{
        identity_id: "user-uuid",
        business_name: "My Business"
      })
      {:ok, provider} = Identity.get_provider_by_identity("user-uuid")
      true = Identity.has_provider_profile?("user-uuid")

      # Children
      children = Identity.get_children("parent-uuid")
      {:ok, child} = Identity.get_child_by_id("child-uuid")

  ## Architecture

  This context follows the Ports & Adapters architecture:
  - Public API (this module) → delegates to use cases
  - Use cases (application layer) → orchestrate domain operations
  - Repository ports (domain layer) → define persistence contracts
  - Repository implementations (adapter layer) → implement persistence
  """

  alias KlassHero.Identity.Application.UseCases.Children.GetChildById
  alias KlassHero.Identity.Application.UseCases.Children.GetChildren
  alias KlassHero.Identity.Application.UseCases.Parents.CreateParentProfile
  alias KlassHero.Identity.Application.UseCases.Parents.GetParentByIdentity
  alias KlassHero.Identity.Application.UseCases.Providers.CreateProviderProfile
  alias KlassHero.Identity.Application.UseCases.Providers.GetProviderByIdentity

  @parent_repository Application.compile_env!(:klass_hero, [
                       :identity,
                       :for_storing_parent_profiles
                     ])
  @provider_repository Application.compile_env!(:klass_hero, [
                         :identity,
                         :for_storing_provider_profiles
                       ])

  # ============================================================================
  # Parent Profile Functions
  # ============================================================================

  @doc """
  Creates a new parent profile.

  Accepts a map with parent attributes. The identity_id is required.

  Returns:
  - `{:ok, ParentProfile.t()}` - Parent profile created successfully
  - `{:error, :duplicate_identity}` - Parent profile already exists
  - `{:error, {:validation_error, errors}}` - Domain validation failed
  - `{:error, changeset}` - Persistence validation failed
  """
  def create_parent_profile(attrs) when is_map(attrs) do
    CreateParentProfile.execute(attrs)
  end

  @doc """
  Retrieves a parent profile by identity ID.

  Returns:
  - `{:ok, ParentProfile.t()}` - Parent profile found
  - `{:error, :not_found}` - No parent profile exists
  """
  def get_parent_by_identity(identity_id) when is_binary(identity_id) do
    GetParentByIdentity.execute(identity_id)
  end

  @doc """
  Checks if a parent profile exists for the given identity ID.

  Returns boolean directly.
  """
  def has_parent_profile?(identity_id) when is_binary(identity_id) do
    @parent_repository.has_profile?(identity_id)
  end

  # ============================================================================
  # Provider Profile Functions
  # ============================================================================

  @doc """
  Creates a new provider profile.

  Accepts a map with provider attributes. The identity_id and business_name are required.

  Returns:
  - `{:ok, ProviderProfile.t()}` - Provider profile created successfully
  - `{:error, :duplicate_identity}` - Provider profile already exists
  - `{:error, {:validation_error, errors}}` - Domain validation failed
  - `{:error, changeset}` - Persistence validation failed
  """
  def create_provider_profile(attrs) when is_map(attrs) do
    CreateProviderProfile.execute(attrs)
  end

  @doc """
  Retrieves a provider profile by identity ID.

  Returns:
  - `{:ok, ProviderProfile.t()}` - Provider profile found
  - `{:error, :not_found}` - No provider profile exists
  """
  def get_provider_by_identity(identity_id) when is_binary(identity_id) do
    GetProviderByIdentity.execute(identity_id)
  end

  @doc """
  Checks if a provider profile exists for the given identity ID.

  Returns boolean directly.
  """
  def has_provider_profile?(identity_id) when is_binary(identity_id) do
    @provider_repository.has_profile?(identity_id)
  end

  # ============================================================================
  # Children Functions
  # ============================================================================

  @doc """
  Lists all children for a parent.

  Returns a list of Child domain entities, ordered by first name then last name.
  Returns an empty list if no children exist.
  """
  def get_children(parent_id) when is_binary(parent_id) do
    GetChildren.execute(parent_id)
  end

  @doc """
  Retrieves a single child by ID.

  Returns:
  - `{:ok, Child.t()}` - Child found
  - `{:error, :not_found}` - No child exists or invalid UUID
  """
  def get_child_by_id(child_id) when is_binary(child_id) do
    GetChildById.execute(child_id)
  end
end
