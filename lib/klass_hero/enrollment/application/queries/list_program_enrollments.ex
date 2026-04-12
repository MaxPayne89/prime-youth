defmodule KlassHero.Enrollment.Application.Queries.ListProgramEnrollments do
  @moduledoc """
  Lists enriched enrollment roster entries for a program.

  Fetches active enrollments, then resolves child names and parent
  identity via ACL ports. Returns a flat list of roster entries with
  child_name, parent_id, parent_user_id, status, and enrolled_at.
  """

  require Logger

  @enrollment_repository Application.compile_env!(:klass_hero, [
                           :enrollment,
                           :for_querying_enrollments
                         ])
  @child_info_adapter Application.compile_env!(:klass_hero, [
                        :enrollment,
                        :for_resolving_child_info
                      ])
  @parent_info_adapter Application.compile_env!(:klass_hero, [
                         :enrollment,
                         :for_resolving_parent_info
                       ])

  @type roster_entry :: %{
          enrollment_id: String.t(),
          child_id: String.t(),
          child_name: String.t(),
          parent_id: String.t(),
          parent_user_id: String.t() | nil,
          status: atom(),
          enrolled_at: DateTime.t()
        }

  @doc """
  Returns enriched roster entries for the given program.

  Each entry contains child_name (resolved via ACL), parent_id,
  parent_user_id (resolved via ACL), enrollment status, and
  enrolled_at timestamp.
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

      parent_ids = enrollments |> Enum.map(& &1.parent_id) |> Enum.uniq()
      parents = @parent_info_adapter.get_parents_by_ids(parent_ids)
      parent_map = Map.new(parents, fn p -> {p.id, p} end)

      Enum.map(enrollments, &build_roster_entry(&1, child_map, parent_map))
    end
  end

  defp build_roster_entry(enrollment, child_map, parent_map) do
    child_name =
      case Map.get(child_map, enrollment.child_id) do
        nil -> "Unknown"
        child -> "#{child.first_name} #{child.last_name}"
      end

    # Trigger: parent profile might not exist (deleted, orphaned enrollment)
    # Why: graceful degradation — roster still displays, messaging button disabled
    # Outcome: nil parent_user_id causes the message button to be disabled in UI
    parent_user_id =
      case Map.get(parent_map, enrollment.parent_id) do
        nil -> nil
        parent -> parent.identity_id
      end

    %{
      enrollment_id: enrollment.id,
      child_id: enrollment.child_id,
      child_name: child_name,
      parent_id: enrollment.parent_id,
      parent_user_id: parent_user_id,
      status: enrollment.status,
      enrolled_at: enrollment.enrolled_at
    }
  end
end
