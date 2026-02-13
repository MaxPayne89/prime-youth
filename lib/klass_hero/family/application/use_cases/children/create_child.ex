defmodule KlassHero.Family.Application.UseCases.Children.CreateChild do
  @moduledoc """
  Use case for creating a new child.

  Orchestrates domain validation and persistence through the repository port.
  """

  alias KlassHero.Family.Domain.Models.Child

  @repository Application.compile_env!(:klass_hero, [:family, :for_storing_children])

  @doc """
  Creates a new child for a parent.

  Returns:
  - `{:ok, Child.t()}` on success
  - `{:error, {:validation_error, errors}}` for domain validation failures
  - `{:error, changeset}` for persistence validation failures
  """
  def execute(attrs) when is_map(attrs) do
    attrs_with_id = Map.put_new(attrs, :id, Ecto.UUID.generate())

    with {:ok, _validated} <- Child.new(attrs_with_id),
         {:ok, persisted} <- @repository.create(attrs_with_id) do
      {:ok, persisted}
    else
      {:error, errors} when is_list(errors) -> {:error, {:validation_error, errors}}
      {:error, _} = error -> error
    end
  end
end
