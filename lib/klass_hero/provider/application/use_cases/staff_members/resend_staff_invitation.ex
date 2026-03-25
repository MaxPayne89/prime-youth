defmodule KlassHero.Provider.Application.UseCases.StaffMembers.ResendStaffInvitation do
  @moduledoc """
  Use case for resending a staff invitation.

  Transitions invitation_status back to :pending, generates a fresh token,
  and re-emits :staff_member_invited to restart the invitation saga.

  Only allowed for staff members in :failed or :expired status.
  """

  alias KlassHero.Provider.Application.UseCases.StaffMembers.InvitationEmitter
  alias KlassHero.Provider.Domain.Models.StaffMember

  require Logger

  @staff_repository Application.compile_env!(:klass_hero, [:provider, :for_storing_staff_members])

  @spec execute(String.t()) ::
          {:ok, StaffMember.t(), String.t()}
          | {:error, :not_found | :invalid_invitation_transition | :invitation_emission_failed}
  def execute(staff_member_id) when is_binary(staff_member_id) do
    with {:ok, staff} <- @staff_repository.get(staff_member_id),
         {:ok, transitioned} <- StaffMember.transition_invitation(staff, :pending),
         {raw_token, token_hash} = StaffMember.generate_invitation_token(),
         updated = %{transitioned | invitation_token_hash: token_hash},
         {:ok, persisted} <- @staff_repository.update(updated) do
      emit_or_compensate(persisted, raw_token)
    end
  end

  defp emit_or_compensate(persisted, raw_token) do
    case InvitationEmitter.emit(persisted, raw_token) do
      :ok -> {:ok, persisted, raw_token}
      {:error, reason} -> compensate_failed_emission(persisted, reason)
    end
  end

  defp compensate_failed_emission(staff_member, reason) do
    Logger.warning("[ResendStaffInvitation] Event emission failed, compensating",
      staff_member_id: staff_member.id,
      reason: inspect(reason)
    )

    with {:ok, failed} <- StaffMember.transition_invitation(staff_member, :failed),
         {:ok, _persisted} <- @staff_repository.update(failed) do
      {:error, :invitation_emission_failed}
    else
      {:error, _} ->
        Logger.error("[ResendStaffInvitation] Compensation failed",
          staff_member_id: staff_member.id
        )

        {:error, :invitation_emission_failed}
    end
  end
end
