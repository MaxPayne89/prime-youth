defmodule KlassHero.Family.Adapters.Driven.Events.InviteClaimedHandler do
  @moduledoc """
  Integration event handler for `:invite_claimed` events from the Enrollment context.

  When a guardian claims a bulk enrollment invite:

  1. Creates a parent profile for the user (idempotent — skips if already exists)
  2. Creates a child record from the invite data, linked to the parent
  3. Publishes `:invite_family_ready` domain event so Enrollment can auto-enroll

  ## Error Handling

  - Duplicate parent profile → treated as success (idempotent)
  - Child creation failure → logged with rich context, returns error
  """

  @behaviour KlassHero.Shared.Domain.Ports.ForHandlingIntegrationEvents

  alias KlassHero.Family
  alias KlassHero.Family.Domain.Events.FamilyEvents
  alias KlassHero.Shared.Domain.Events.IntegrationEvent
  alias KlassHero.Shared.EventDispatchHelper

  require Logger

  @impl true
  def subscribed_events, do: [:invite_claimed]

  @impl true
  def handle_event(%IntegrationEvent{
        event_type: :invite_claimed,
        entity_id: invite_id,
        payload: payload
      }) do
    user_id = Map.fetch!(payload, :user_id)
    program_id = Map.fetch!(payload, :program_id)

    with {:ok, parent} <- ensure_parent_profile(user_id, invite_id),
         {:ok, child} <- create_child_from_invite(parent.id, payload, invite_id, user_id),
         :ok <- publish_family_ready(invite_id, user_id, child.id, parent.id, program_id) do
      Logger.info("[InviteClaimedHandler] Family ready for invite",
        invite_id: invite_id,
        user_id: user_id,
        parent_id: parent.id,
        child_id: child.id,
        program_id: program_id
      )

      :ok
    else
      {:error, reason} ->
        Logger.error("[InviteClaimedHandler] Failed to process invite_claimed",
          invite_id: invite_id,
          user_id: user_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  def handle_event(_event), do: :ignore

  # Trigger: user may already have a parent profile from a prior invite or registration
  # Why: idempotent — create if missing, fetch if exists
  # Outcome: always returns {:ok, parent} or propagates unexpected error
  defp ensure_parent_profile(user_id, invite_id) do
    case Family.create_parent_profile(%{identity_id: user_id}) do
      {:ok, parent} ->
        {:ok, parent}

      {:error, :duplicate_resource} ->
        Family.get_parent_by_identity(user_id)

      {:error, reason} ->
        Logger.error("[InviteClaimedHandler] Failed to create parent profile",
          invite_id: invite_id,
          user_id: user_id,
          step: :ensure_parent_profile,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  # Trigger: invite payload contains child data that needs to be mapped to domain fields
  # Why: invite fields use different names than the Child domain model
  # Outcome: child found (idempotent) or created and linked to parent via guardian relationship
  defp create_child_from_invite(parent_id, payload, invite_id, user_id) do
    first_name = Map.get(payload, :child_first_name)
    last_name = Map.get(payload, :child_last_name)
    date_of_birth = Map.get(payload, :child_date_of_birth)

    # Trigger: event may replay after a crash or redelivery
    # Why: children table has no uniqueness constraint; unconditional create produces duplicates
    # Outcome: find existing child by (first_name, last_name, date_of_birth) for this parent
    case find_existing_child(parent_id, first_name, last_name, date_of_birth) do
      %{} = child ->
        Logger.info("[InviteClaimedHandler] Child already exists, skipping creation",
          invite_id: invite_id,
          child_id: child.id,
          parent_id: parent_id
        )

        {:ok, child}

      nil ->
        child_attrs = %{
          parent_id: parent_id,
          first_name: first_name,
          last_name: last_name,
          date_of_birth: date_of_birth,
          school_grade: Map.get(payload, :school_grade),
          school_name: Map.get(payload, :school_name),
          support_needs: Map.get(payload, :medical_conditions),
          allergies: map_nut_allergy(Map.get(payload, :nut_allergy, false))
        }

        case Family.create_child(child_attrs) do
          {:ok, child} ->
            {:ok, child}

          {:error, reason} ->
            Logger.error("[InviteClaimedHandler] Failed to create child",
              invite_id: invite_id,
              user_id: user_id,
              parent_id: parent_id,
              step: :create_child,
              reason: inspect(reason)
            )

            {:error, reason}
        end
    end
  end

  # Trigger: need to check for duplicate child before creating
  # Why: uses public Family API (not direct repository access) to respect context boundaries
  # Outcome: returns matching child or nil
  defp find_existing_child(parent_id, first_name, last_name, date_of_birth) do
    parent_id
    |> Family.get_children()
    |> Enum.find(fn child ->
      child.first_name == first_name &&
        child.last_name == last_name &&
        child.date_of_birth == date_of_birth
    end)
  end

  # Trigger: nut_allergy boolean from invite needs to become a human-readable string
  # Why: Child.allergies is a free-text string field, not a boolean
  # Outcome: true → "Nut allergy", false/nil → nil
  defp map_nut_allergy(true), do: "Nut allergy"
  defp map_nut_allergy(_), do: nil

  defp publish_family_ready(invite_id, user_id, child_id, parent_id, program_id) do
    FamilyEvents.invite_family_ready(invite_id, %{
      invite_id: invite_id,
      user_id: user_id,
      child_id: child_id,
      parent_id: parent_id,
      program_id: program_id
    })
    |> EventDispatchHelper.dispatch_or_error(KlassHero.Family)
  end
end
