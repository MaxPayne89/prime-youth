defmodule KlassHero.Provider.Adapters.Driven.Persistence.Mappers.ProgramStaffAssignmentMapper do
  @moduledoc """
  Maps between domain ProgramStaffAssignment entities and ProgramStaffAssignmentSchema Ecto structs.
  """

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProgramStaffAssignmentSchema
  alias KlassHero.Provider.Domain.Models.ProgramStaffAssignment

  @spec to_domain(ProgramStaffAssignmentSchema.t()) :: ProgramStaffAssignment.t()
  def to_domain(%ProgramStaffAssignmentSchema{} = schema) do
    %ProgramStaffAssignment{
      id: to_string(schema.id),
      provider_id: to_string(schema.provider_id),
      program_id: to_string(schema.program_id),
      staff_member_id: to_string(schema.staff_member_id),
      assigned_at: schema.assigned_at,
      unassigned_at: schema.unassigned_at,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end
