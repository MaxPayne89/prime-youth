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

  alias KlassHero.Provider.Domain.Models.StaffMember
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  require Logger

  @repository Application.compile_env!(:klass_hero, [:provider, :for_storing_staff_members])

  @impl true
  def subscribed_events,
    do: [:staff_invitation_sent, :staff_invitation_failed, :staff_user_registered]

  @impl true
  def handle_event(%IntegrationEvent{event_type: :staff_invitation_sent, payload: payload}) do
    payload = normalize_keys(payload)
    staff_member_id = Map.fetch!(payload, :staff_member_id)

    with {:ok, staff} <- @repository.get(staff_member_id),
         {:ok, transitioned} <- StaffMember.transition_invitation(staff, :sent),
         updated = %{transitioned | invitation_sent_at: DateTime.utc_now()},
         {:ok, _persisted} <- @repository.update(updated) do
      Logger.info(
        "[StaffInvitationStatusHandler] Staff invitation marked as sent",
        staff_member_id: staff_member_id
      )

      :ok
    else
      {:error, :invalid_invitation_transition} ->
        # Idempotent: already in :sent or later state
        Logger.info(
          "[StaffInvitationStatusHandler] Skipping transition (already past :pending)",
          staff_member_id: staff_member_id
        )

        :ok

      {:error, reason} ->
        Logger.error(
          "[StaffInvitationStatusHandler] Failed to update status to :sent",
          staff_member_id: staff_member_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  def handle_event(%IntegrationEvent{event_type: :staff_invitation_failed, payload: payload}) do
    payload = normalize_keys(payload)
    staff_member_id = Map.fetch!(payload, :staff_member_id)

    with {:ok, staff} <- @repository.get(staff_member_id),
         {:ok, transitioned} <- StaffMember.transition_invitation(staff, :failed),
         {:ok, _persisted} <- @repository.update(transitioned) do
      Logger.warning(
        "[StaffInvitationStatusHandler] Staff invitation failed (compensating)",
        staff_member_id: staff_member_id,
        reason: Map.get(payload, :reason)
      )

      :ok
    else
      {:error, :invalid_invitation_transition} ->
        Logger.info(
          "[StaffInvitationStatusHandler] Skipping failed transition (already past :pending)",
          staff_member_id: staff_member_id
        )

        :ok

      {:error, reason} ->
        Logger.error(
          "[StaffInvitationStatusHandler] Failed to update status to :failed",
          staff_member_id: staff_member_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  def handle_event(%IntegrationEvent{event_type: :staff_user_registered, payload: payload}) do
    payload = normalize_keys(payload)
    staff_member_id = Map.fetch!(payload, :staff_member_id)
    user_id = Map.fetch!(payload, :user_id)

    with {:ok, staff} <- @repository.get(staff_member_id),
         {:ok, transitioned} <- StaffMember.transition_invitation(staff, :accepted),
         updated = %{transitioned | user_id: user_id},
         {:ok, _persisted} <- @repository.update(updated) do
      Logger.info(
        "[StaffInvitationStatusHandler] Staff account linked",
        staff_member_id: staff_member_id,
        user_id: user_id
      )

      :ok
    else
      {:error, :invalid_invitation_transition} ->
        # Idempotent: already accepted
        Logger.info(
          "[StaffInvitationStatusHandler] Skipping (already accepted)",
          staff_member_id: staff_member_id
        )

        :ok

      {:error, reason} ->
        Logger.error(
          "[StaffInvitationStatusHandler] Failed to link staff account",
          staff_member_id: staff_member_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  def handle_event(_event), do: :ignore

  defp normalize_keys(payload) when is_map(payload) do
    Map.new(payload, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} when is_atom(k) -> {k, v}
    end)
  end
end
