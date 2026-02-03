defmodule KlassHero.Identity.Application.UseCases.Children.DeleteChild do
  @moduledoc """
  Use case for deleting a child and all associated records.

  Deletes consent records first to satisfy FK constraints,
  then deletes the child itself within a transaction.
  """

  @repo Application.compile_env!(:klass_hero, [:identity, :repo])
  @child_repo Application.compile_env!(:klass_hero, [:identity, :for_storing_children])
  @consent_repo Application.compile_env!(:klass_hero, [:identity, :for_storing_consents])

  @doc """
  Deletes a child and all associated consents by child ID.

  Returns:
  - `:ok` on success
  - `{:error, :not_found}` if child doesn't exist
  - `{:error, {:consent_deletion_failed, reason}}` if consent cleanup fails
  """
  def execute(child_id) when is_binary(child_id) do
    # Trigger: child deletion requested
    # Why: consents FK constraint is RESTRICT, so consents must be deleted first
    # Outcome: both consents and child are removed atomically
    @repo.transaction(fn ->
      # Trigger: consents have FK RESTRICT constraint on child_id
      # Why: must delete consents before the child or PostgreSQL rejects the delete
      # Outcome: consent records removed, child deletion can proceed
      {:ok, _count} = @consent_repo.delete_all_for_child(child_id)

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
