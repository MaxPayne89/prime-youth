defmodule KlassHero.Family do
  @moduledoc """
  Public API for the Family bounded context.

  Manages parent profiles, children, consents, and referral codes.
  Split from the former Identity context to give Family its own
  bounded context with clear domain boundaries.

  ## Usage

      # Parent Profiles
      {:ok, parent} = Family.create_parent_profile(%{identity_id: "user-uuid"})
      {:ok, parent} = Family.get_parent_by_identity("user-uuid")
      true = Family.has_parent_profile?("user-uuid")

      # Children
      children = Family.get_children("parent-uuid")
      {:ok, child} = Family.get_child_by_id("child-uuid")
  """

  use Boundary,
    top_level?: true,
    deps: [KlassHero, KlassHero.Shared],
    exports: [
      Domain.Models.Child,
      Domain.Models.ParentProfile,
      Domain.Models.Consent,
      Adapters.Driven.Persistence.ChangeChild,
      # Schema exported for Enrollment's enrollment→parent_profile join
      Adapters.Driven.Persistence.Schemas.ParentProfileSchema
    ]

  alias KlassHero.Family.Adapters.Driven.Persistence.ChangeChild
  alias KlassHero.Family.Application.UseCases.Children.CreateChild
  alias KlassHero.Family.Application.UseCases.Children.DeleteChild
  alias KlassHero.Family.Application.UseCases.Children.UpdateChild
  alias KlassHero.Family.Application.UseCases.Consents.GrantConsent
  alias KlassHero.Family.Application.UseCases.Consents.WithdrawConsent
  alias KlassHero.Family.Application.UseCases.Parents.CreateParentProfile
  alias KlassHero.Family.Domain.Events.FamilyEvents
  alias KlassHero.Family.Domain.Models.Child
  alias KlassHero.Family.Domain.Services.ReferralCodeGenerator
  alias KlassHero.Shared.Domain.Services.ActivityGoalCalculator
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @parent_repository Application.compile_env!(:klass_hero, [
                       :family,
                       :for_storing_parent_profiles
                     ])
  @child_repository Application.compile_env!(:klass_hero, [
                      :family,
                      :for_storing_children
                    ])
  @consent_repository Application.compile_env!(:klass_hero, [
                        :family,
                        :for_storing_consents
                      ])

  # ============================================================================
  # Parent Profile Functions
  # ============================================================================

  @doc """
  Creates a new parent profile.

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
  """
  def has_parent_profile?(identity_id) when is_binary(identity_id) do
    @parent_repository.has_profile?(identity_id)
  end

  # ============================================================================
  # Children Functions
  # ============================================================================

  @doc """
  Lists all children for a parent, ordered by first name then last name.
  """
  def get_children(parent_id) when is_binary(parent_id) do
    @child_repository.list_by_guardian(parent_id)
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
  """
  def change_child(attrs \\ %{})

  def change_child(attrs) when is_map(attrs) and not is_struct(attrs) do
    ChangeChild.execute(attrs)
  end

  def change_child(%Child{} = child) do
    ChangeChild.execute(child)
  end

  @doc """
  Returns a changeset for tracking child form changes on an existing child.
  """
  def change_child(%Child{} = child, attrs) when is_map(attrs) do
    ChangeChild.execute(child, attrs)
  end

  @doc """
  Retrieves multiple children by their IDs.

  Missing or invalid IDs are silently excluded from the result.
  """
  def get_children_by_ids(child_ids) when is_list(child_ids) do
    @child_repository.list_by_ids(child_ids)
  end

  @doc """
  Returns a MapSet of child IDs that have active consent of the given type.
  """
  def children_with_active_consents(child_ids, consent_type)
      when is_list(child_ids) and is_binary(consent_type) do
    @consent_repository.list_active_for_children(child_ids, consent_type)
    |> MapSet.new(& &1.child_id)
  end

  @doc """
  Returns a MapSet of child IDs for a given parent.
  """
  def get_child_ids_for_parent(parent_id) when is_binary(parent_id) do
    parent_id
    |> get_children()
    |> MapSet.new(& &1.id)
  end

  @doc """
  Checks if a child belongs to a specific parent.
  """
  def child_belongs_to_parent?(child_id, parent_id)
      when is_binary(child_id) and is_binary(parent_id) do
    @child_repository.child_belongs_to_guardian?(child_id, parent_id)
  end

  # ============================================================================
  # Consent Functions
  # ============================================================================

  @doc """
  Grants a new consent for a child.

  Expects a map with :parent_id, :child_id, and :consent_type.
  """
  def grant_consent(attrs) when is_map(attrs) do
    GrantConsent.execute(attrs)
  end

  @doc """
  Withdraws the active consent for a child and consent type.
  """
  def withdraw_consent(child_id, consent_type)
      when is_binary(child_id) and is_binary(consent_type) do
    WithdrawConsent.execute(child_id, consent_type)
  end

  @doc """
  Checks if a child has an active consent of the given type.
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
        Logger.warning("[Family] child_has_active_consent? failed",
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
  Anonymizes all Family-owned data for a user during GDPR account deletion.

  Looks up the user's parent profile, then for each child:
  1. Deletes all consent records
  2. Anonymizes child PII (names, emergency contact, support needs, allergies)
  3. Publishes `child_data_anonymized` event for downstream contexts

  Returns:
  - `{:ok, :no_data}` if user has no parent profile
  - `{:ok, %{children_anonymized: count, consents_deleted: count}}`
  """
  def anonymize_data_for_user(identity_id) when is_binary(identity_id) do
    case @parent_repository.get_by_identity_id(identity_id) do
      {:ok, parent} ->
        children = @child_repository.list_by_guardian(parent.id)
        anonymize_children_data(children)

      {:error, :not_found} ->
        {:ok, :no_data}
    end
  end

  defp anonymize_children_data(children) do
    anonymized_child_attrs = Child.anonymized_attrs()

    Enum.reduce_while(
      children,
      {:ok, %{children_anonymized: 0, consents_deleted: 0}},
      fn child, {:ok, acc} ->
        with {:ok, consent_count} <- @consent_repository.delete_all_for_child(child.id),
             {:ok, _anonymized_child} <-
               @child_repository.anonymize(child.id, anonymized_child_attrs),
             # Trigger: child PII anonymized and consents deleted
             # Why: downstream contexts own their own child data and must clean it
             # Outcome: Participation context will anonymize behavioral notes
             :ok <- dispatch_child_anonymized(child.id) do
          {:cont,
           {:ok,
            %{
              acc
              | children_anonymized: acc.children_anonymized + 1,
                consents_deleted: acc.consents_deleted + consent_count
            }}}
        else
          {:error, reason} ->
            Logger.error("[Family] anonymize_children_data failed",
              child_id: child.id,
              reason: inspect(reason)
            )

            {:halt, {:error, reason}}
        end
      end
    )
  end

  # Trigger: DomainEventBus.dispatch returns {:error, [{:error, reason} | _]}
  # Why: the `with` chain and tests expect a flat {:error, reason} shape
  # Outcome: unwraps the first handler failure from the bus error list
  defp dispatch_child_anonymized(child_id) do
    case DomainEventBus.dispatch(
           KlassHero.Family,
           FamilyEvents.child_data_anonymized(child_id)
         ) do
      :ok -> :ok
      {:error, [{:error, reason} | _]} -> {:error, reason}
    end
  end

  # ============================================================================
  # GDPR Data Export
  # ============================================================================

  @doc """
  Exports all Family-owned personal data for a user.

  Returns `%{children: [...]}` when the user has a parent profile,
  or `%{}` when no parent profile exists.
  """
  def export_data_for_user(identity_id) when is_binary(identity_id) do
    case @parent_repository.get_by_identity_id(identity_id) do
      {:ok, parent} ->
        children = @child_repository.list_by_guardian(parent.id)

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
  """
  def calculate_activity_goal(children, opts \\ []) when is_list(children) do
    ActivityGoalCalculator.calculate(children, opts)
  end

  @doc """
  Generates a referral code for a user.

  Options:
  - `:location` - Location string (default: "BERLIN")
  - `:year_suffix` - Year suffix string (default: current year's last 2 digits)
  """
  def generate_referral_code(name, opts \\ []) when is_binary(name) do
    ReferralCodeGenerator.generate(name, opts)
  end
end
