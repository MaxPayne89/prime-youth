defmodule KlassHero.Provider.Application.Commands.StaffMembers.ExpireStaffInvitation do
  @moduledoc """
  Command for transitioning a staff member's invitation status to :expired.

  Called by the invitation LiveView on lazy expiry detection.
  """

  alias KlassHero.Provider.Domain.Models.StaffMember

  @staff_query Application.compile_env!(:klass_hero, [
                 :provider,
                 :for_querying_staff_members
               ])
  @staff_repository Application.compile_env!(:klass_hero, [
                      :provider,
                      :for_storing_staff_members
                    ])

  @doc """
  Expires a staff invitation.

  Accepts either a `StaffMember` domain model or a staff member ID string.
  When given an ID, fetches the staff member first, then transitions.
  """
  @spec execute(StaffMember.t() | String.t()) :: {:ok, StaffMember.t()} | {:error, term()}
  def execute(%StaffMember{} = staff) do
    with {:ok, updated} <- StaffMember.transition_invitation(staff, :expired) do
      @staff_repository.update(updated)
    end
  end

  def execute(staff_member_id) when is_binary(staff_member_id) do
    with {:ok, staff} <- @staff_query.get(staff_member_id) do
      execute(staff)
    end
  end
end
