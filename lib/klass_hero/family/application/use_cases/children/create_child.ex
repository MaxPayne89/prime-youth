defmodule KlassHero.Family.Application.UseCases.Children.CreateChild do
  @moduledoc """
  Use case for creating a new child.

  Orchestrates domain validation and persistence through the repository port.
  When a parent_id is provided, the child is atomically linked to the guardian.
  """

  alias KlassHero.Family.Domain.Models.Child

  @repository Application.compile_env!(:klass_hero, [:family, :for_storing_children])

  @doc """
  Creates a new child, optionally linking it to a guardian (parent).

  Expects `parent_id` in attrs to establish the guardian relationship.
  The child itself does not carry a parent_id; the relationship is
  managed through the children_guardians join table via the repository port.

  Returns:
  - `{:ok, Child.t()}` on success
  - `{:error, {:validation_error, errors}}` for domain validation failures
  - `{:error, changeset}` for persistence validation failures
  """
  def execute(attrs) when is_map(attrs) do
    # Trigger: parent_id is provided in attrs for guardian link creation
    # Why: child does not own parent_id — relationship lives in join table
    # Outcome: parent_id is extracted, child is created (with or without link)
    {parent_id, child_attrs} = Map.pop(attrs, :parent_id)
    child_attrs = Map.put_new(child_attrs, :id, Ecto.UUID.generate())

    with {:ok, _validated} <- Child.new(child_attrs),
         {:ok, persisted} <- persist_child(child_attrs, parent_id) do
      {:ok, persisted}
    else
      {:error, errors} when is_list(errors) -> {:error, {:validation_error, errors}}
      {:error, _} = error -> error
    end
  end

  # Trigger: no guardian specified
  # Why: some children may be created without an immediate guardian link
  # Outcome: child created without a guardian relationship
  defp persist_child(attrs, nil), do: @repository.create(attrs)

  # Trigger: guardian_id provided
  # Why: child and guardian link must be created atomically
  # Outcome: both child and guardian link created in a single transaction
  defp persist_child(attrs, guardian_id), do: @repository.create_with_guardian(attrs, guardian_id)
end
