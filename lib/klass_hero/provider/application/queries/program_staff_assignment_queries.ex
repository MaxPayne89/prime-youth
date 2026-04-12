defmodule KlassHero.Provider.Application.Queries.ProgramStaffAssignmentQueries do
  @moduledoc """
  Query module for program staff assignment reads.

  Centralises all read operations that depend on the assignment repository,
  keeping the facade free of direct repository references.
  """

  alias KlassHero.Provider.Domain.Models.ProgramStaffAssignment

  @assignment_repository Application.compile_env!(:klass_hero, [
                           :provider,
                           :for_querying_program_staff_assignments
                         ])

  @doc """
  Lists all active staff assignments for a program.
  """
  @spec list_active_for_program(String.t()) :: [ProgramStaffAssignment.t()]
  def list_active_for_program(program_id) when is_binary(program_id) do
    @assignment_repository.list_active_for_program(program_id)
  end

  @doc """
  Lists all active staff assignments for a provider.
  """
  @spec list_active_for_provider(String.t()) :: [ProgramStaffAssignment.t()]
  def list_active_for_provider(provider_id) when is_binary(provider_id) do
    @assignment_repository.list_active_for_provider(provider_id)
  end

  @doc """
  Lists all active program assignments for a staff member.
  """
  @spec list_active_for_staff_member(String.t()) :: [ProgramStaffAssignment.t()]
  def list_active_for_staff_member(staff_member_id) when is_binary(staff_member_id) do
    @assignment_repository.list_active_for_staff_member(staff_member_id)
  end
end
