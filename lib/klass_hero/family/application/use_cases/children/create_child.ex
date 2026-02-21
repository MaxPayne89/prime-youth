defmodule KlassHero.Family.Application.UseCases.Children.CreateChild do
  @moduledoc """
  Use case for creating a new child.

  Orchestrates domain validation, persistence through the repository port,
  and creation of the guardian link in children_guardians.
  """

  alias KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildGuardianSchema
  alias KlassHero.Family.Domain.Models.Child
  alias KlassHero.Repo

  require Logger

  @repository Application.compile_env!(:klass_hero, [:family, :for_storing_children])

  @doc """
  Creates a new child and links it to a guardian (parent).

  Expects `parent_id` in attrs to establish the guardian relationship.
  The child itself no longer carries a parent_id; the relationship is
  stored in the children_guardians join table.

  Returns:
  - `{:ok, Child.t()}` on success
  - `{:error, {:validation_error, errors}}` for domain validation failures
  - `{:error, changeset}` for persistence validation failures
  """
  def execute(attrs) when is_map(attrs) do
    # Trigger: parent_id is provided in attrs for guardian link creation
    # Why: child no longer owns parent_id — relationship lives in join table
    # Outcome: parent_id is extracted, child is created without it, then linked
    {parent_id, child_attrs} = Map.pop(attrs, :parent_id)
    child_attrs = Map.put_new(child_attrs, :id, Ecto.UUID.generate())

    with {:ok, _validated} <- Child.new(child_attrs),
         {:ok, persisted} <- @repository.create(child_attrs),
         :ok <- create_guardian_link(persisted.id, parent_id) do
      {:ok, persisted}
    else
      {:error, errors} when is_list(errors) -> {:error, {:validation_error, errors}}
      {:error, _} = error -> error
    end
  end

  defp create_guardian_link(_child_id, nil), do: :ok

  defp create_guardian_link(child_id, guardian_id) do
    changeset =
      ChildGuardianSchema.changeset(%{
        child_id: child_id,
        guardian_id: guardian_id,
        relationship: "parent",
        is_primary: true
      })

    case Repo.insert(changeset) do
      {:ok, _} ->
        :ok

      {:error, changeset} ->
        Logger.warning(
          "[Family.CreateChild] Failed to create guardian link",
          child_id: child_id,
          guardian_id: guardian_id,
          errors: changeset.errors
        )

        {:error, changeset}
    end
  end
end
