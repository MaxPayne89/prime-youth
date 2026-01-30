defmodule KlassHero.Identity.Application.UseCases.Children.DeleteChild do
  @moduledoc """
  Use case for deleting a child.

  Delegates to the repository port for deletion.
  """

  @repository Application.compile_env!(:klass_hero, [:identity, :for_storing_children])

  @doc """
  Deletes a child by ID.

  Returns:
  - `:ok` on success
  - `{:error, :not_found}` if child doesn't exist
  """
  def execute(child_id) when is_binary(child_id) do
    @repository.delete(child_id)
  end
end
