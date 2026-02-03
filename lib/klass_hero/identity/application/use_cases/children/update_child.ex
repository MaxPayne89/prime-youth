defmodule KlassHero.Identity.Application.UseCases.Children.UpdateChild do
  @moduledoc """
  Use case for updating an existing child.

  Loads the child, validates updated fields at the domain level,
  then persists via the repository port.
  """

  alias KlassHero.Identity.Domain.Models.Child

  @repository Application.compile_env!(:klass_hero, [:identity, :for_storing_children])

  @doc """
  Updates an existing child with the given attributes.

  Returns:
  - `{:ok, Child.t()}` on success
  - `{:error, :not_found}` if child doesn't exist
  - `{:error, {:validation_error, errors}}` for domain validation failures
  - `{:error, changeset}` for persistence validation failures
  """
  def execute(child_id, attrs) when is_binary(child_id) and is_map(attrs) do
    with {:ok, existing} <- @repository.get_by_id(child_id),
         merged = Map.merge(Map.from_struct(existing), attrs),
         {:ok, _validated} <- Child.new(merged),
         {:ok, updated} <- @repository.update(child_id, attrs) do
      {:ok, updated}
    else
      {:error, errors} when is_list(errors) -> {:error, {:validation_error, errors}}
      {:error, _} = error -> error
    end
  end
end
