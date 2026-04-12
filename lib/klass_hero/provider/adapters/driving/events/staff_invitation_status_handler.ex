defmodule KlassHero.Provider.Adapters.Driving.Events.StaffInvitationStatusHandler do
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

  @behaviour KlassHero.Shared.Domain.Ports.Driving.ForHandlingIntegrationEvents

  alias KlassHero.Provider.Application.Commands.Providers.CreateProviderProfile
  alias KlassHero.Provider.Domain.Models.StaffMember
  alias KlassHero.Shared.Adapters.Driven.Persistence.MapperHelpers
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  require Logger

  @repository Application.compile_env!(:klass_hero, [:provider, :for_storing_staff_members])

  @impl true
  def subscribed_events, do: [:staff_invitation_sent, :staff_invitation_failed, :staff_user_registered]

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
         :ok <-
           transition_and_persist(payload, :accepted, fn transitioned ->
             %{transitioned | user_id: user_id}
           end) do
      if payload[:create_provider_profile] do
        maybe_create_provider_profile(user_id, payload)
      else
        :ok
      end
    else
      :error ->
        Logger.error("[StaffInvitationStatusHandler] Missing :user_id in staff_user_registered payload")

        {:error, :invalid_payload}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_event(_event), do: :ignore

  defp maybe_create_provider_profile(user_id, payload) do
    # Check existence first to avoid a failed INSERT that taints the
    # wrapping Repo.transaction (Postgres constraint errors are not recoverable
    # within the same transaction, even if we catch them in Elixir).
    if KlassHero.Provider.has_provider_profile?(user_id) do
      Logger.info("[StaffInvitationStatusHandler] Provider profile already exists",
        user_id: user_id
      )

      :ok
    else
      business_name = payload[:user_name] || "My Business"

      case CreateProviderProfile.execute(%{
             identity_id: user_id,
             business_name: business_name,
             originated_from: :staff_invite
           }) do
        {:ok, profile} ->
          Logger.info("[StaffInvitationStatusHandler] Created provider profile for staff user",
            user_id: user_id,
            provider_id: profile.id
          )

          :ok

        {:error, :duplicate_resource} ->
          Logger.info("[StaffInvitationStatusHandler] Provider profile already exists (race)",
            user_id: user_id
          )

          :ok

        {:error, reason} ->
          Logger.error("[StaffInvitationStatusHandler] Failed to create provider profile",
            user_id: user_id,
            reason: inspect(reason)
          )

          {:error, reason}
      end
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
