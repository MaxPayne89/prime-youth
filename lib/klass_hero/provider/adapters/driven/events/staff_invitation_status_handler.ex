defmodule KlassHero.Provider.Adapters.Driven.Events.StaffInvitationStatusHandler do
  @moduledoc """
  Integration event handler for staff invitation status updates from Accounts context.

  Reacts to:
  - `:staff_invitation_sent` — status :pending → :sent, sets `invitation_sent_at`
  - `:staff_invitation_failed` — status :pending → :failed (compensation)
  - `:staff_user_registered` — status :sent/:pending → :accepted, links `user_id`

  All handlers are idempotent: if the transition is already past the expected
  source state, the handler treats `{:error, :invalid_invitation_transition}` as
  success and logs accordingly.
  """

  @behaviour KlassHero.Shared.Domain.Ports.ForHandlingIntegrationEvents

  alias KlassHero.Provider.Application.UseCases.Providers.CreateProviderProfile
  alias KlassHero.Provider.Domain.Models.StaffMember
  alias KlassHero.Shared.Adapters.Driven.Persistence.MapperHelpers
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  require Logger

  @repository Application.compile_env!(:klass_hero, [:provider, :for_storing_staff_members])

  @impl true
  def subscribed_events,
    do: [:staff_invitation_sent, :staff_invitation_failed, :staff_user_registered]

  @impl true
  def handle_event(%IntegrationEvent{event_type: :staff_invitation_sent, payload: payload}) do
    payload = MapperHelpers.normalize_keys(payload)

    transition_and_persist(payload, :sent, fn transitioned ->
      %{transitioned | invitation_sent_at: DateTime.utc_now()}
    end)
  end

  def handle_event(%IntegrationEvent{event_type: :staff_invitation_failed, payload: payload}) do
    payload = MapperHelpers.normalize_keys(payload)
    transition_and_persist(payload, :failed)
  end

  def handle_event(%IntegrationEvent{event_type: :staff_user_registered, payload: payload}) do
    payload = MapperHelpers.normalize_keys(payload)

    with {:ok, user_id} <- Map.fetch(payload, :user_id),
         {:ok, staff_member_id} <- Map.fetch(payload, :staff_member_id),
         {:ok, staff} <- @repository.get(staff_member_id),
         {:ok, transitioned} <- StaffMember.transition_invitation(staff, :accepted),
         updated = %{transitioned | user_id: user_id},
         {:ok, _persisted} <- @repository.update(updated) do
      Logger.info("[StaffInvitationStatusHandler] Transitioned to :accepted",
        staff_member_id: staff_member_id,
        user_id: user_id
      )

      # Create a starter provider profile for the newly activated staff member.
      # Intentionally runs after the staff transition commits — not atomic with it.
      # Oban retry + CreateProviderProfile idempotency handle failure recovery.
      create_provider_profile_for_staff(user_id, staff)

      :ok
    else
      :error ->
        Logger.error(
          "[StaffInvitationStatusHandler] Missing required key in :staff_user_registered payload"
        )

        {:error, :invalid_payload}

      {:error, :invalid_invitation_transition} ->
        Logger.info(
          "[StaffInvitationStatusHandler] Skipping :staff_user_registered (already past :accepted)",
          staff_member_id: payload[:staff_member_id]
        )

        :ok

      {:error, reason} ->
        Logger.error(
          "[StaffInvitationStatusHandler] Failed to handle :staff_user_registered",
          staff_member_id: payload[:staff_member_id],
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  def handle_event(_event), do: :ignore

  defp create_provider_profile_for_staff(user_id, %StaffMember{} = staff) do
    result =
      CreateProviderProfile.execute(%{
        identity_id: user_id,
        business_name: StaffMember.full_name(staff),
        subscription_tier: :starter,
        originated_from: :staff_invite
      })

    case result do
      {:ok, _profile} ->
        Logger.info("[StaffInvitationStatusHandler] Created provider profile for staff member",
          identity_id: user_id
        )

      {:error, :duplicate_resource} ->
        Logger.info(
          "[StaffInvitationStatusHandler] Provider profile already exists — idempotent",
          identity_id: user_id
        )

      {:error, reason} ->
        Logger.error(
          "[StaffInvitationStatusHandler] Failed to create provider profile",
          identity_id: user_id,
          reason: inspect(reason)
        )

        # Do NOT re-raise. The staff member transition is already committed.
        # Oban will retry the job; CreateProviderProfile is idempotent.
    end
  end

  defp transition_and_persist(payload, new_status, update_fn \\ &Function.identity/1) do
    with {:ok, staff_member_id} <- Map.fetch(payload, :staff_member_id),
         {:ok, staff} <- @repository.get(staff_member_id),
         {:ok, transitioned} <- StaffMember.transition_invitation(staff, new_status),
         updated = update_fn.(transitioned),
         {:ok, _persisted} <- @repository.update(updated) do
      Logger.info("[StaffInvitationStatusHandler] Transitioned to #{new_status}",
        staff_member_id: staff_member_id
      )

      :ok
    else
      :error ->
        Logger.error("[StaffInvitationStatusHandler] Missing :staff_member_id in payload")
        {:error, :invalid_payload}

      {:error, :invalid_invitation_transition} ->
        Logger.info("[StaffInvitationStatusHandler] Skipping (already past #{new_status})",
          staff_member_id: payload[:staff_member_id]
        )

        :ok

      {:error, reason} ->
        Logger.error("[StaffInvitationStatusHandler] Failed to transition to #{new_status}",
          staff_member_id: payload[:staff_member_id],
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end
end
