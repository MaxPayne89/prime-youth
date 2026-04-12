defmodule KlassHero.Family.Application.Queries.Children.PrepareChildDeletion do
  @moduledoc """
  Use case for checking if a child can be safely deleted.

  Queries active enrollments to determine if a confirmation warning
  should be shown to the parent before deletion.
  """

  require Logger

  @enrollment_acl Application.compile_env!(:klass_hero, [
                    :family,
                    :for_managing_child_enrollments
                  ])

  @doc """
  Checks if a child has active enrollments.

  Returns:
  - `{:ok, :no_enrollments}` -- safe to delete without warning
  - `{:ok, :has_enrollments, program_titles}` -- show confirmation with program names
  - `{:error, :enrollment_check_failed}` -- database or infrastructure error
  """
  def execute(child_id) when is_binary(child_id) do
    # Trigger: child_id passed to enrollment ACL port
    # Why: determine whether parent needs a warning before deletion
    # Outcome: empty list means safe to delete; non-empty triggers confirmation UI
    case list_enrollments(child_id) do
      {:ok, []} ->
        {:ok, :no_enrollments}

      {:ok, enrollments} ->
        program_titles = Enum.map(enrollments, & &1.program_title)
        {:ok, :has_enrollments, program_titles}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Trigger: Repo.all/1 raises on DB connection errors
  # Why: isolate infrastructure failures at the use case boundary
  # Outcome: callers get {:error, :enrollment_check_failed} instead of a crash
  defp list_enrollments(child_id) do
    {:ok, @enrollment_acl.list_active_with_program_titles(child_id)}
  rescue
    error ->
      Logger.error("[PrepareChildDeletion] Enrollment check failed: #{inspect(error)}",
        child_id: child_id
      )

      {:error, :enrollment_check_failed}
  end
end
