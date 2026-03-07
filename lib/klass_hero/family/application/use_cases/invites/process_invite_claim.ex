defmodule KlassHero.Family.Application.UseCases.Invites.ProcessInviteClaim do
  @moduledoc """
  Use case for processing an invite claim into a family unit.

  Orchestrates: ensure parent profile, find-or-create child, publish
  `invite_family_ready` event. Called by the Oban worker, which serializes
  execution per parent to prevent duplicate children.
  """

  alias KlassHero.Family
  alias KlassHero.Family.Domain.Events.FamilyEvents
  alias KlassHero.Shared.EventDispatchHelper

  require Logger

  @doc """
  Processes an invite claim by setting up the family unit.

  Expects a map with:
  - `:invite_id` - The invite being claimed
  - `:user_id` - The claiming user's identity ID
  - `:program_id` - The program the child is being enrolled in
  - `:child_first_name`, `:child_last_name`, `:child_date_of_birth` - Child identity
  - `:school_grade`, `:school_name`, `:medical_conditions`, `:nut_allergy` - Optional fields

  Returns:
  - `{:ok, %{parent: ParentProfile.t(), child: Child.t()}}` on success
  - `{:error, reason}` on failure
  """
  def execute(attrs) when is_map(attrs) do
    user_id = Map.fetch!(attrs, :user_id)
    invite_id = Map.fetch!(attrs, :invite_id)
    program_id = Map.fetch!(attrs, :program_id)

    with {:ok, parent} <- ensure_parent_profile(user_id, invite_id),
         {:ok, child} <- find_or_create_child(parent.id, attrs),
         :ok <- publish_family_ready(invite_id, user_id, child.id, parent.id, program_id) do
      {:ok, %{parent: parent, child: child}}
    else
      {:error, reason} ->
        Logger.error("[ProcessInviteClaim] Failed",
          invite_id: invite_id,
          user_id: user_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  # Trigger: user may already have a parent profile from a prior invite or registration
  # Why: idempotent -- create if missing, fetch if exists
  # Outcome: always returns {:ok, parent} or propagates unexpected error
  defp ensure_parent_profile(user_id, invite_id) do
    case Family.create_parent_profile(%{identity_id: user_id}) do
      {:ok, parent} ->
        {:ok, parent}

      {:error, :duplicate_resource} ->
        Family.get_parent_by_identity(user_id)

      {:error, reason} ->
        Logger.error("[ProcessInviteClaim] Failed to create parent profile",
          invite_id: invite_id,
          user_id: user_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  # Trigger: invite payload contains child data mapped to domain fields
  # Why: same child may be enrolled in multiple programs -- avoid duplicates
  # Outcome: child found (idempotent) or created and linked to parent
  defp find_or_create_child(parent_id, attrs) do
    invite_id = Map.get(attrs, :invite_id)
    user_id = Map.get(attrs, :user_id)
    first_name = Map.get(attrs, :child_first_name)
    last_name = Map.get(attrs, :child_last_name)
    date_of_birth = Map.get(attrs, :child_date_of_birth)

    # Trigger: event may replay after a crash or redelivery
    # Why: children table has no uniqueness constraint; unconditional create produces duplicates
    # Outcome: find existing child by (first_name, last_name, date_of_birth) for this parent
    case find_existing_child(parent_id, first_name, last_name, date_of_birth) do
      %{} = child ->
        Logger.info("[ProcessInviteClaim] Child already exists, skipping creation",
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
          school_grade: Map.get(attrs, :school_grade),
          school_name: Map.get(attrs, :school_name),
          support_needs: Map.get(attrs, :medical_conditions),
          allergies: map_nut_allergy(Map.get(attrs, :nut_allergy, false))
        }

        case Family.create_child(child_attrs) do
          {:ok, child} ->
            {:ok, child}

          {:error, reason} ->
            Logger.error("[ProcessInviteClaim] Failed to create child",
              invite_id: invite_id,
              user_id: user_id,
              parent_id: parent_id,
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
  # Outcome: true -> "Nut allergy", false/nil -> nil
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
