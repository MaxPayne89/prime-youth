defmodule KlassHero.Family.Application.UseCases.Children.DeleteChild do
  @moduledoc """
  Use case for deleting a child and all associated records.

  Cleans up cross-context data (enrollments, participation records) via
  ACL adapters, then deletes Family-owned data (consents, child) within
  a single transaction.
  """

  @repo Application.compile_env!(:klass_hero, [:family, :repo])
  @child_repo Application.compile_env!(:klass_hero, [:family, :for_storing_children])
  @consent_repo Application.compile_env!(:klass_hero, [:family, :for_storing_consents])
  @enrollment_acl Application.compile_env!(:klass_hero, [
                    :family,
                    :for_managing_child_enrollments
                  ])
  @participation_acl Application.compile_env!(:klass_hero, [
                       :family,
                       :for_managing_child_participation
                     ])

  @doc """
  Deletes a child and all associated records across contexts.

  Transaction order (satisfies FK constraints):
  1. Delete consents (Family-owned, FK RESTRICT on child_id)
  2. Cancel active enrollments (cross-context via ACL)
  3. Delete behavioral notes + participation records (cross-context via ACL)
  4. Delete child (FK cascade handles children_guardians, nilify handles enrollments)

  Returns:
  - `:ok` on success
  - `{:error, :not_found}` if child doesn't exist
  """
  def execute(child_id) when is_binary(child_id) do
    @repo.transaction(fn ->
      with {:ok, _} <- tag_step(:delete_consents, @consent_repo.delete_all_for_child(child_id)),
           {:ok, _} <-
             tag_step(:cancel_enrollments, @enrollment_acl.cancel_active_for_child(child_id)),
           {:ok, _} <-
             tag_step(:delete_participation, @participation_acl.delete_all_for_child(child_id)),
           :ok <- tag_step(:delete_child, @child_repo.delete(child_id)) do
        :ok
      else
        {:error, reason} -> @repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:error, {:delete_child, :not_found}} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  # Passes through success, tags errors with the step name for traceability
  defp tag_step(_step, {:ok, _} = result), do: result
  defp tag_step(_step, :ok), do: :ok
  defp tag_step(step, {:error, reason}), do: {:error, {step, reason}}
end
