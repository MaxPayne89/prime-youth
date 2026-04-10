defmodule KlassHero.Enrollment.Application.UseCases.ListEnrolledChildFirstNamesForParent do
  @moduledoc """
  Returns the first names of children enrolled by a specific parent in a program.

  Used by the Messaging context to enrich the direct conversation header
  with context about which children the conversation relates to.

  Returns [] when:
  - The program has no enrollments
  - The parent has no enrollments in the program
  - ACL resolution fails (graceful degradation)
  """

  require Logger

  @enrollment_repository Application.compile_env!(:klass_hero, [
                           :enrollment,
                           :for_managing_enrollments
                         ])
  @child_info_adapter Application.compile_env!(:klass_hero, [
                        :enrollment,
                        :for_resolving_child_info
                      ])
  @parent_info_adapter Application.compile_env!(:klass_hero, [
                         :enrollment,
                         :for_resolving_parent_info
                       ])

  @doc """
  Returns the first names of children enrolled by the given parent in a program.

  `parent_user_id` is the user's identity_id (i.e. `user.id` from Accounts).
  """
  @spec execute(String.t(), String.t()) :: [String.t()]
  def execute(program_id, parent_user_id) when is_binary(program_id) and is_binary(parent_user_id) do
    Logger.debug(
      "[Enrollment.ListEnrolledChildFirstNamesForParent] Resolving child names",
      program_id: program_id,
      parent_user_id: parent_user_id
    )

    case @enrollment_repository.list_by_program(program_id) do
      [] ->
        []

      enrollments ->
        parent_ids = enrollments |> Enum.map(& &1.parent_id) |> Enum.uniq()
        parents = @parent_info_adapter.get_parents_by_ids(parent_ids)

        case Enum.find(parents, fn p -> p.identity_id == parent_user_id end) do
          nil ->
            []

          matching_parent ->
            child_ids =
              enrollments
              |> Enum.filter(fn e -> e.parent_id == matching_parent.id end)
              |> Enum.map(& &1.child_id)
              |> Enum.uniq()

            @child_info_adapter.get_children_by_ids(child_ids)
            |> Enum.map(& &1.first_name)
        end
    end
  end
end
