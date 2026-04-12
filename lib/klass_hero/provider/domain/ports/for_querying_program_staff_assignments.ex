defmodule KlassHero.Provider.Domain.Ports.ForQueryingProgramStaffAssignments do
  @moduledoc """
  Read-only port for querying program staff assignments in the Provider bounded context.

  Separated from `ForStoringProgramStaffAssignments` (write-only) to support CQRS at
  the port level. Read operations never mutate state.
  """

  alias KlassHero.Provider.Domain.Models.ProgramStaffAssignment

  @callback list_active_for_program(program_id :: String.t()) :: [ProgramStaffAssignment.t()]

  @callback list_active_for_staff_member(staff_member_id :: String.t()) :: [
              ProgramStaffAssignment.t()
            ]

  @callback list_active_for_provider(provider_id :: String.t()) :: [ProgramStaffAssignment.t()]
end
