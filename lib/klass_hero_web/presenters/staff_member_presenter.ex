defmodule KlassHeroWeb.Presenters.StaffMemberPresenter do
  @moduledoc """
  Transforms StaffMember domain models to view-ready formats.
  """

  alias KlassHero.Provider.Domain.Models.StaffMember

  @spec to_card_view(StaffMember.t()) :: map()
  def to_card_view(%StaffMember{} = staff) do
    %{
      id: staff.id,
      full_name: StaffMember.full_name(staff),
      initials: StaffMember.initials(staff),
      first_name: staff.first_name,
      last_name: staff.last_name,
      role: staff.role,
      email: staff.email,
      bio: staff.bio,
      headshot_url: staff.headshot_url,
      tags: staff.tags || [],
      qualifications: staff.qualifications || [],
      active: staff.active,
      invitation_status: staff.invitation_status,
      invitation_status_label: invitation_status_label(staff.invitation_status),
      can_resend?: staff.invitation_status in [:failed, :expired]
    }
  end

  @spec to_card_view_list([StaffMember.t()]) :: [map()]
  def to_card_view_list(staff_members) when is_list(staff_members) do
    Enum.map(staff_members, &to_card_view/1)
  end

  defp invitation_status_label(nil), do: nil
  defp invitation_status_label(:pending), do: "Invitation Pending"
  defp invitation_status_label(:sent), do: "Invitation Sent"
  defp invitation_status_label(:failed), do: "Invitation Failed"
  defp invitation_status_label(:accepted), do: "Joined"
  defp invitation_status_label(:expired), do: "Invitation Expired"
end
