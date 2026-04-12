defmodule KlassHero.Provider.Domain.Ports.ForStoringProgramStaffAssignments do
  @moduledoc """
  Write-only port for storing program staff assignments in the Provider bounded context.

  Read operations have been moved to `ForQueryingProgramStaffAssignments`.

  Defines the contract for program staff assignment write operations.
  Implemented by adapters in the infrastructure layer.
  """

  alias KlassHero.Provider.Domain.Models.ProgramStaffAssignment

  @callback create(attrs :: map()) ::
              {:ok, ProgramStaffAssignment.t()} | {:error, :already_assigned | term()}

  @callback unassign(program_id :: String.t(), staff_member_id :: String.t()) ::
              {:ok, ProgramStaffAssignment.t()} | {:error, :not_found | term()}
end
