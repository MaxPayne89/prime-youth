defmodule KlassHero.ProgramCatalog.Application.UseCases.UpdateProgram do
  @moduledoc """
  Use case for updating an existing program.

  Orchestrates: load aggregate -> apply changes through domain model -> persist.
  Delegates persistence (including optimistic locking) to the repository adapter.
  """

  alias KlassHero.ProgramCatalog.Domain.Models.Program

  require Logger

  @repository Application.compile_env!(:klass_hero, [:program_catalog, :repository])

  def execute(id, changes) when is_binary(id) and is_map(changes) do
    Logger.info("[UpdateProgram] Starting program update", program_id: id)

    with {:ok, program} <- @repository.get_by_id(id),
         {:ok, updated} <- Program.apply_changes(program, changes),
         {:ok, persisted} <- @repository.update(updated) do
      Logger.info("[UpdateProgram] Program updated successfully", program_id: id)
      {:ok, persisted}
    else
      {:error, :not_found} = error ->
        Logger.info("[UpdateProgram] Program not found", program_id: id)
        error

      {:error, :stale_data} = error ->
        Logger.warning("[UpdateProgram] Stale data conflict", program_id: id)
        error

      {:error, errors} = error when is_list(errors) ->
        Logger.warning("[UpdateProgram] Domain validation failed",
          program_id: id,
          errors: inspect(errors)
        )

        error

      {:error, _changeset} = error ->
        Logger.warning("[UpdateProgram] Persistence validation failed", program_id: id)
        error
    end
  end
end
