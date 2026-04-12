defmodule KlassHero.Family.Application.Queries.Consents.ConsentQueries do
  @moduledoc """
  Queries for consent read operations.
  """

  @consent_repository Application.compile_env!(:klass_hero, [
                        :family,
                        :for_storing_consents
                      ])

  @doc """
  Returns a MapSet of child IDs that have active consent of the given type.
  """
  def children_with_active_consents(child_ids, consent_type) do
    @consent_repository.list_active_for_children(child_ids, consent_type)
    |> MapSet.new(& &1.child_id)
  end

  @doc """
  Checks if a child has an active consent of the given type.
  """
  @spec child_has_active_consent?(binary(), String.t()) :: boolean()
  def child_has_active_consent?(child_id, consent_type) do
    case @consent_repository.get_active_for_child(child_id, consent_type) do
      {:ok, _} -> true
      {:error, :not_found} -> false
    end
  end
end
