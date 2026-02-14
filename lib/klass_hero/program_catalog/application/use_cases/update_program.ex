defmodule KlassHero.ProgramCatalog.Application.UseCases.UpdateProgram do
  @moduledoc """
  Use case for updating an existing program.

  Orchestrates: load aggregate -> apply changes through domain model -> persist.
  Optimistic locking via lock_version on the loaded aggregate.
  """

  alias KlassHero.ProgramCatalog.Domain.Models.Program

  @repository Application.compile_env!(:klass_hero, [:program_catalog, :repository])

  def execute(id, changes) when is_binary(id) and is_map(changes) do
    with {:ok, program} <- @repository.get_by_id(id),
         {:ok, updated} <- Program.apply_changes(program, changes) do
      @repository.update(updated)
    end
  end
end
