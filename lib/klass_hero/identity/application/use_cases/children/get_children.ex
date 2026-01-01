defmodule KlassHero.Identity.Application.UseCases.Children.GetChildren do
  @moduledoc """
  Use case for retrieving all children for a parent.

  Returns children ordered by first name, then last name.
  """

  @repository Application.compile_env!(:klass_hero, [:identity, :for_storing_children])

  @doc """
  Lists all children for the given parent ID.

  Returns a list of Child domain entities (may be empty).
  """
  def execute(parent_id) when is_binary(parent_id) do
    @repository.list_by_parent(parent_id)
  end
end
