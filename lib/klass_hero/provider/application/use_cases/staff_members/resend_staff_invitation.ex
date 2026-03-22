defmodule KlassHero.Provider.Application.UseCases.StaffMembers.ResendStaffInvitation do
  @moduledoc """
  Use case for resending a staff invitation.

  Transitions invitation_status back to :pending, generates a fresh token,
  and re-emits :staff_member_invited to restart the invitation saga.

  Only allowed for staff members in :failed or :expired status.
  """

  alias KlassHero.Provider.Application.UseCases.StaffMembers.InvitationEmitter
  alias KlassHero.Provider.Domain.Models.StaffMember

  @staff_repository Application.compile_env!(:klass_hero, [:provider, :for_storing_staff_members])

  @spec execute(String.t()) ::
          {:ok, StaffMember.t(), String.t()}
          | {:error, :not_found | :invalid_invitation_transition}
  def execute(staff_member_id) when is_binary(staff_member_id) do
    with {:ok, staff} <- @staff_repository.get(staff_member_id),
         {:ok, transitioned} <- StaffMember.transition_invitation(staff, :pending) do
      {raw_token, token_hash} = StaffMember.generate_invitation_token()

      updated = %{transitioned | invitation_token_hash: token_hash}

      with {:ok, persisted} <- @staff_repository.update(updated),
           :ok <- InvitationEmitter.emit(persisted, raw_token) do
        {:ok, persisted, raw_token}
      end
    end
  end
end
