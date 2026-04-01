defmodule KlassHero.Provider.Domain.Ports.ForStoringProgramStaffAssignments do
  @moduledoc """
  Repository port for storing and retrieving program staff assignments in the Provider bounded context.

  Defines the contract for program staff assignment persistence.
  Implemented by adapters in the infrastructure layer.
  """

  alias KlassHero.Provider.Domain.Models.ProgramStaffAssignment

  @callback create(attrs :: map()) ::
              {:ok, ProgramStaffAssignment.t()} | {:error, :already_assigned | term()}

  @callback unassign(program_id :: String.t(), staff_member_id :: String.t()) ::
              {:ok, ProgramStaffAssignment.t()} | {:error, :not_found}

  @callback list_active_for_program(program_id :: String.t()) :: [ProgramStaffAssignment.t()]

  @callback list_active_for_staff_member(staff_member_id :: String.t()) :: [
              ProgramStaffAssignment.t()
            ]

  @callback list_active_for_provider(provider_id :: String.t()) :: [ProgramStaffAssignment.t()]
end
