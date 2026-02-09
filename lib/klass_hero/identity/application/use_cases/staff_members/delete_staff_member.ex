defmodule KlassHero.Identity.Application.UseCases.StaffMembers.DeleteStaffMember do
  @moduledoc """
  Use case for deleting a staff member.
  """

  @repository Application.compile_env!(:klass_hero, [:identity, :for_storing_staff_members])

  def execute(staff_id) when is_binary(staff_id) do
    @repository.delete(staff_id)
  end
end
