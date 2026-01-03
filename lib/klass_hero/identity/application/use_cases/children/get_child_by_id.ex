defmodule KlassHero.Identity.Application.UseCases.Children.GetChildById do
  @moduledoc """
  Use case for retrieving a single child by ID.

  Simple delegation to repository - no additional business logic required.
  """

  @repository Application.compile_env!(:klass_hero, [:identity, :for_storing_children])

  @doc """
  Retrieves a child by ID.

  Returns:
  - `{:ok, Child.t()}` when found
  - `{:error, :not_found}` when no child exists or invalid UUID
  """
  def execute(child_id) when is_binary(child_id) do
    @repository.get_by_id(child_id)
  end
end
