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

  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ChildSchema
  alias KlassHero.Identity.Application.UseCases.Children.CreateChild
  alias KlassHero.Identity.Application.UseCases.Children.DeleteChild
  alias KlassHero.Identity.Application.UseCases.Children.UpdateChild
  alias KlassHero.Identity.Application.UseCases.Consents.GrantConsent
  alias KlassHero.Identity.Application.UseCases.Consents.WithdrawConsent
  alias KlassHero.Identity.Application.UseCases.Parents.CreateParentProfile
  alias KlassHero.Identity.Application.UseCases.Providers.CreateProviderProfile
  alias KlassHero.Identity.Domain.Models.Child
  alias KlassHero.Identity.Domain.Services.ReferralCodeGenerator
  alias KlassHero.Identity.EventPublisher
  alias KlassHero.Shared.Domain.Services.ActivityGoalCalculator

  require Logger

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
  Returns a changeset for tracking child form changes.

  Used by LiveView forms for `to_form()` and `phx-change` validation.
  Excludes `parent_id` from cast since it is set programmatically.

  ## Examples

      Identity.change_child(%{})
      Identity.change_child(%Child{...}, %{first_name: "Emma"})
  """
  def change_child(attrs \\ %{})

  def change_child(attrs) when is_map(attrs) and not is_struct(attrs) do
    ChildSchema.form_changeset(%ChildSchema{}, attrs)
  end

  def change_child(%Child{} = child) do
    child |> child_to_schema() |> ChildSchema.form_changeset(%{})
  end

  @doc """
  Returns a changeset for tracking child form changes on an existing child.

  Accepts a `%Child{}` domain struct and form attributes.
  """
  def change_child(%Child{} = child, attrs) when is_map(attrs) do
    child |> child_to_schema() |> ChildSchema.form_changeset(attrs)
  end

  defp child_to_schema(%Child{} = child) do
    %ChildSchema{
      id: child.id,
      parent_id: child.parent_id,
      first_name: child.first_name,
      last_name: child.last_name,
      date_of_birth: child.date_of_birth,
      emergency_contact: child.emergency_contact,
      support_needs: child.support_needs,
      allergies: child.allergies
    }
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
      {:ok, child} ->
        child.parent_id == parent_id

      {:error, :not_found} ->
        false

      # Trigger: unexpected error from repository (e.g. database issue)
      # Why: authorization check must fail closed — never grant access on error
      {:error, reason} ->
        Logger.warning("[Identity] child_belongs_to_parent? failed",
          child_id: child_id,
          parent_id: parent_id,
          reason: inspect(reason)
        )

        false
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
      {:ok, _} ->
        true

      {:error, :not_found} ->
        false

      # Trigger: unexpected error from consent repository (e.g. database issue)
      # Why: consent check must fail closed — never expose data on error
      {:error, reason} ->
        Logger.warning("[Identity] child_has_active_consent? failed",
          child_id: child_id,
          consent_type: consent_type,
          reason: inspect(reason)
        )

        false
    end
  end

  # ============================================================================
  # GDPR Account Anonymization
  # ============================================================================

  @doc """
  Anonymizes all Identity-owned data for a user during GDPR account deletion.

  Looks up the user's parent profile, then for each child:
  1. Deletes all consent records
  2. Anonymizes child PII (names, emergency contact, support needs, allergies)
  3. Publishes `child_data_anonymized` event for downstream contexts

  Parent profile itself has no PII (only identity_id, subscription_tier, timestamps)
  so it requires no anonymization.

  Downstream contexts (e.g. Participation) react to the `child_data_anonymized`
  event to anonymize their own child-related data.

  Returns:
  - `{:ok, :no_data}` if user has no parent profile
  - `{:ok, %{children_anonymized: count, consents_deleted: count}}`
  """
  def anonymize_data_for_user(identity_id) when is_binary(identity_id) do
    case @parent_repository.get_by_identity_id(identity_id) do
      {:ok, parent} ->
        children = @child_repository.list_by_parent(parent.id)
        anonymize_children_data(children)

      {:error, :not_found} ->
        {:ok, :no_data}
    end
  end

  defp anonymize_children_data(children) do
    anonymized_child_attrs = Child.anonymized_attrs()

    result =
      Enum.reduce_while(
        children,
        %{children_anonymized: 0, consents_deleted: 0},
        fn child, acc ->
          with {:ok, consent_count} <- @consent_repository.delete_all_for_child(child.id),
               {:ok, _anonymized_child} <-
                 @child_repository.anonymize(child.id, anonymized_child_attrs) do
            # Trigger: child PII anonymized and consents deleted
            # Why: downstream contexts own their own child data and must clean it
            # Outcome: Participation context will anonymize behavioral notes
            EventPublisher.publish_child_data_anonymized(child.id)

            {:cont,
             %{
               acc
               | children_anonymized: acc.children_anonymized + 1,
                 consents_deleted: acc.consents_deleted + consent_count
             }}
          else
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end
      )

    case result do
      {:error, reason} -> {:error, reason}
      summary -> {:ok, summary}
    end
  end

  # ============================================================================
  # GDPR Data Export
  # ============================================================================

  @doc """
  Exports all Identity-owned personal data for a user.

  Looks up the user's parent profile, then collects all children and their
  full consent history (including withdrawn records for audit purposes).

  Returns `%{children: [...]}` when the user has a parent profile,
  or `%{}` when no parent profile exists.
  """
  def export_data_for_user(identity_id) when is_binary(identity_id) do
    case @parent_repository.get_by_identity_id(identity_id) do
      {:ok, parent} ->
        children = @child_repository.list_by_parent(parent.id)

        children_data =
          Enum.map(children, fn child ->
            consents = @consent_repository.list_all_by_child(child.id)
            format_child_export(child, consents)
          end)

        %{children: children_data}

      {:error, :not_found} ->
        %{}
    end
  end

  defp format_child_export(child, consents) do
    %{
      id: child.id,
      first_name: child.first_name,
      last_name: child.last_name,
      date_of_birth: Date.to_iso8601(child.date_of_birth),
      emergency_contact: child.emergency_contact,
      support_needs: child.support_needs,
      allergies: child.allergies,
      created_at: format_datetime(child.inserted_at),
      updated_at: format_datetime(child.updated_at),
      consents: Enum.map(consents, &format_consent_export/1)
    }
  end

  defp format_consent_export(consent) do
    %{
      id: consent.id,
      consent_type: consent.consent_type,
      granted_at: format_datetime(consent.granted_at),
      withdrawn_at: format_datetime(consent.withdrawn_at),
      created_at: format_datetime(consent.inserted_at),
      updated_at: format_datetime(consent.updated_at)
    }
  end

  defp format_datetime(nil), do: nil
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

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
