defmodule KlassHero.Family.Application.UseCases.Children.PrepareChildDeletion do
  @moduledoc """
  Use case for checking if a child can be safely deleted.

  Queries active enrollments to determine if a confirmation warning
  should be shown to the parent before deletion.
  """

  @enrollment_acl Application.compile_env!(:klass_hero, [
                    :family,
                    :for_managing_child_enrollments
                  ])

  @doc """
  Checks if a child has active enrollments.

  Returns:
  - `{:ok, :no_enrollments}` -- safe to delete without warning
  - `{:ok, :has_enrollments, program_titles}` -- show confirmation with program names
  """
  def execute(child_id) when is_binary(child_id) do
    # Trigger: child_id passed to enrollment ACL port
    # Why: determine whether parent needs a warning before deletion
    # Outcome: empty list means safe to delete; non-empty triggers confirmation UI
    case @enrollment_acl.list_active_with_program_titles(child_id) do
      [] ->
        {:ok, :no_enrollments}

      enrollments ->
        program_titles = Enum.map(enrollments, & &1.program_title)
        {:ok, :has_enrollments, program_titles}
    end
  end
end
