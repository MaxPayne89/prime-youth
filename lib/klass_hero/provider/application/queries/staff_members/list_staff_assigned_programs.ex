defmodule KlassHero.Provider.Application.Queries.StaffMembers.ListStaffAssignedPrograms do
  @moduledoc """
  Filters a list of programs to only those assigned to a staff member.

  Accepts the staff member and a pre-fetched list of programs (from the
  calling context), then applies the domain service filter by tags.

  The cross-context program fetch is performed by the caller (web layer
  or facade) to avoid a dependency cycle between Provider and ProgramCatalog.
  """

  alias KlassHero.Provider.Domain.Models.StaffMember
  alias KlassHero.Provider.Domain.Services.StaffProgramFilter

  @spec execute(StaffMember.t(), [map()]) :: [map()]
  def execute(%StaffMember{} = staff_member, programs) when is_list(programs) do
    StaffProgramFilter.filter_by_tags(programs, staff_member.tags)
  end
end
