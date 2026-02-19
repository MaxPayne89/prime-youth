defmodule KlassHero.Enrollment.Application.UseCases.ListProgramEnrollments do
  @moduledoc """
  Lists enriched enrollment roster entries for a program.

  Fetches active enrollments, then resolves child names via the
  ForResolvingChildInfo ACL port. Returns a flat list of roster
  entries with child_name, status, and enrolled_at.
  """

  require Logger

  @enrollment_repository Application.compile_env!(:klass_hero, [:enrollment, :for_managing_enrollments])
  @child_info_adapter Application.compile_env!(:klass_hero, [:enrollment, :for_resolving_child_info])

  @type roster_entry :: %{
          enrollment_id: String.t(),
          child_id: String.t(),
          child_name: String.t(),
          status: atom(),
          enrolled_at: DateTime.t()
        }

  @doc """
  Returns enriched roster entries for the given program.

  Each entry contains child_name (resolved via ACL), enrollment status,
  and enrolled_at timestamp.
  """
  @spec execute(binary()) :: [roster_entry()]
  def execute(program_id) when is_binary(program_id) do
    Logger.info("[Enrollment.ListProgramEnrollments] Listing roster", program_id: program_id)

    enrollments = @enrollment_repository.list_by_program(program_id)

    # Trigger: no enrollments exist for this program
    # Why: skip the ACL call entirely when there's nothing to enrich
    # Outcome: return empty list immediately
    if enrollments == [] do
      []
    else
      child_ids = enrollments |> Enum.map(& &1.child_id) |> Enum.uniq()
      children = @child_info_adapter.get_children_by_ids(child_ids)
      child_map = Map.new(children, fn c -> {c.id, c} end)

      Enum.map(enrollments, &build_roster_entry(&1, child_map))
    end
  end

  defp build_roster_entry(enrollment, child_map) do
    child_name =
      case Map.get(child_map, enrollment.child_id) do
        nil -> "Unknown"
        child -> "#{child.first_name} #{child.last_name}"
      end

    %{
      enrollment_id: enrollment.id,
      child_id: enrollment.child_id,
      child_name: child_name,
      status: enrollment.status,
      enrolled_at: enrollment.enrolled_at
    }
  end
end
