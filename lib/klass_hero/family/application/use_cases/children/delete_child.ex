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
      # Trigger: consents have FK RESTRICT constraint on child_id
      # Why: must delete consents before the child or PostgreSQL rejects the delete
      # Outcome: consent records removed
      {:ok, _count} = @consent_repo.delete_all_for_child(child_id)

      # Trigger: enrollments have FK nilify_all on child_id
      # Why: cancelling preserves audit trail for providers; child deletion nullifies child_id
      # Outcome: active enrollments set to "cancelled" status
      {:ok, _count} = @enrollment_acl.cancel_active_for_child(child_id)

      # Trigger: behavioral_notes.child_id has ON DELETE: nothing, participation_records has FK RESTRICT
      # Why: ACL deletes behavioral notes first, then participation records
      # Outcome: all participation data for this child removed
      {:ok, _count} = @participation_acl.delete_all_for_child(child_id)

      case @child_repo.delete(child_id) do
        :ok -> :ok
        {:error, reason} -> @repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end
end
