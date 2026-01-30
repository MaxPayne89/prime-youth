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

  alias KlassHero.Identity.Application.UseCases.Children.CreateChild
  alias KlassHero.Identity.Application.UseCases.Children.DeleteChild
  alias KlassHero.Identity.Application.UseCases.Children.UpdateChild
  alias KlassHero.Identity.Application.UseCases.Consents.GrantConsent
  alias KlassHero.Identity.Application.UseCases.Consents.WithdrawConsent
  alias KlassHero.Identity.Application.UseCases.Parents.CreateParentProfile
  alias KlassHero.Identity.Application.UseCases.Providers.CreateProviderProfile
  alias KlassHero.Identity.Domain.Services.ReferralCodeGenerator
  alias KlassHero.Shared.Domain.Services.ActivityGoalCalculator

  @parent_repository Application.compile_env!(:klass_hero, [
                       :identity,
                       :for_storing_parent_profiles
                     ])
  @provider_repository Application.compile_env!(:klass_hero, [
                         :identity,
                         :for_storing_provider_profiles
                       ])
  @child_repository Application.compile_env!(:klass_hero, [
                      :identity,
                      :for_storing_children
                    ])
  @consent_repository Application.compile_env!(:klass_hero, [
                        :identity,
                        :for_storing_consents
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
    @parent_repository.get_by_identity_id(identity_id)
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
    @provider_repository.get_by_identity_id(identity_id)
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
    @child_repository.list_by_parent(parent_id)
  end

  @doc """
  Retrieves a single child by ID.

  Returns:
  - `{:ok, Child.t()}` - Child found
  - `{:error, :not_found}` - No child exists or invalid UUID
  """
  def get_child_by_id(child_id) when is_binary(child_id) do
    @child_repository.get_by_id(child_id)
  end

  @doc """
  Creates a new child for a parent.

  Returns:
  - `{:ok, Child.t()}` on success
  - `{:error, {:validation_error, errors}}` for domain validation failures
  - `{:error, changeset}` for persistence validation failures
  """
  def create_child(attrs) when is_map(attrs) do
    CreateChild.execute(attrs)
  end

  @doc """
  Updates an existing child.

  Returns:
  - `{:ok, Child.t()}` on success
  - `{:error, :not_found}` if child doesn't exist
  - `{:error, {:validation_error, errors}}` for domain validation failures
  - `{:error, changeset}` for persistence validation failures
  """
  def update_child(child_id, attrs) when is_binary(child_id) and is_map(attrs) do
    UpdateChild.execute(child_id, attrs)
  end

  @doc """
  Deletes a child by ID.

  Returns:
  - `:ok` on success
  - `{:error, :not_found}` if child doesn't exist
  """
  def delete_child(child_id) when is_binary(child_id) do
    DeleteChild.execute(child_id)
  end

  @doc """
  Returns a MapSet of child IDs for a given parent.
  Useful for authorization checks when processing multiple children.
  """
  def get_child_ids_for_parent(parent_id) when is_binary(parent_id) do
    parent_id
    |> get_children()
    |> MapSet.new(& &1.id)
  end

  @doc """
  Checks if a child belongs to a specific parent.
  Returns true if the child's parent_id matches the given parent_id.
  """
  def child_belongs_to_parent?(child_id, parent_id)
      when is_binary(child_id) and is_binary(parent_id) do
    case get_child_by_id(child_id) do
      {:ok, child} -> child.parent_id == parent_id
      {:error, :not_found} -> false
    end
  end

  # ============================================================================
  # Consent Functions
  # ============================================================================

  @doc """
  Grants a new consent for a child.

  Expects a map with :parent_id, :child_id, and :consent_type.

  Returns:
  - `{:ok, Consent.t()}` on success
  - `{:error, {:validation_error, errors}}` for domain validation failures
  - `{:error, changeset}` for persistence validation failures
  """
  def grant_consent(attrs) when is_map(attrs) do
    GrantConsent.execute(attrs)
  end

  @doc """
  Withdraws the active consent for a child and consent type.

  Returns:
  - `{:ok, Consent.t()}` on success (with withdrawn_at set)
  - `{:error, :not_found}` if no active consent exists
  """
  def withdraw_consent(child_id, consent_type)
      when is_binary(child_id) and is_binary(consent_type) do
    WithdrawConsent.execute(child_id, consent_type)
  end

  @doc """
  Checks if a child has an active consent of the given type.

  Returns boolean directly.
  """
  def child_has_active_consent?(child_id, consent_type)
      when is_binary(child_id) and is_binary(consent_type) do
    case @consent_repository.get_active_for_child(child_id, consent_type) do
      {:ok, _} -> true
      {:error, :not_found} -> false
    end
  end

  # ============================================================================
  # Activity & Referral Functions
  # ============================================================================

  @doc """
  Calculates the weekly activity goal progress for a family's children.

  Options:
  - `:target` - Weekly session target (default: 5)

  Returns a map with:
  - `current` - Number of sessions completed
  - `target` - Target number of sessions
  - `percentage` - Progress percentage (capped at 100)
  - `status` - One of `:achieved`, `:almost_there`, or `:in_progress`
  """
  def calculate_activity_goal(children, opts \\ []) when is_list(children) do
    ActivityGoalCalculator.calculate(children, opts)
  end

  @doc """
  Generates a referral code for a user.

  Options:
  - `:location` - Location string (default: "BERLIN")
  - `:year_suffix` - Year suffix string (default: current year's last 2 digits)

  Returns a string in format "{FIRST_NAME}-{LOCATION}-{YEAR_SUFFIX}"
  """
  def generate_referral_code(name, opts \\ []) when is_binary(name) do
    ReferralCodeGenerator.generate(name, opts)
  end
end
