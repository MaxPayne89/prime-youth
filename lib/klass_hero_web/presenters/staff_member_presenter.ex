defmodule KlassHeroWeb.Presenters.StaffMemberPresenter do
  @moduledoc """
  Transforms StaffMember domain models to view-ready formats.
  """

  alias KlassHero.Identity.Domain.Models.StaffMember

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
      active: staff.active
    }
  end

  def to_card_view_list(staff_members) when is_list(staff_members) do
    Enum.map(staff_members, &to_card_view/1)
  end
end
