defmodule KlassHero.Family.Application.Queries.Children.ChildQueries do
  @moduledoc """
  Queries for child read operations.
  """

  @child_repository Application.compile_env!(:klass_hero, [
                      :family,
                      :for_storing_children
                    ])

  @doc """
  Lists all children for a parent, ordered by first name then last name.
  """
  def list_by_guardian(parent_id) do
    @child_repository.list_by_guardian(parent_id)
  end

  @doc """
  Retrieves a single child by ID.

  Returns:
  - `{:ok, Child.t()}` - Child found
  - `{:error, :not_found}` - No child exists or invalid UUID
  """
  def get_by_id(child_id) do
    @child_repository.get_by_id(child_id)
  end

  @doc """
  Retrieves multiple children by their IDs.

  Missing or invalid IDs are silently excluded from the result.
  """
  def list_by_ids(child_ids) do
    @child_repository.list_by_ids(child_ids)
  end

  @doc """
  Checks if a child belongs to a specific parent.
  """
  @spec belongs_to_guardian?(binary(), binary()) :: boolean()
  def belongs_to_guardian?(child_id, parent_id) do
    @child_repository.child_belongs_to_guardian?(child_id, parent_id)
  end

  @doc """
  Returns a MapSet of child IDs for a given parent.
  """
  def child_ids_for_guardian(parent_id) do
    parent_id
    |> list_by_guardian()
    |> MapSet.new(& &1.id)
  end
end
