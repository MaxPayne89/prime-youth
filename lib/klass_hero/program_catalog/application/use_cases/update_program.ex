defmodule KlassHero.ProgramCatalog.Application.UseCases.UpdateProgram do
  @moduledoc """
  Use case for updating an existing program.

  Orchestrates: load aggregate -> apply changes through domain model -> persist.
  Delegates persistence (including optimistic locking) to the repository adapter.
  """

  alias KlassHero.ProgramCatalog.Domain.Events.ProgramEvents
  alias KlassHero.ProgramCatalog.Domain.Models.Program
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @repository Application.compile_env!(:klass_hero, [:program_catalog, :repository])

  def execute(id, changes) when is_binary(id) and is_map(changes) do
    Logger.info("[UpdateProgram] Starting program update", program_id: id)

    with {:ok, program} <- @repository.get_by_id(id),
         {:ok, updated} <- Program.apply_changes(program, changes),
         {:ok, persisted} <- @repository.update(updated) do
      # Trigger: scheduling fields may have changed
      # Why: downstream consumers need to know about schedule changes
      # Outcome: fire-and-forget event dispatch, failures logged
      maybe_dispatch_schedule_event(program, persisted)
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

  @scheduling_fields ~w(meeting_days meeting_start_time meeting_end_time start_date end_date)a

  defp maybe_dispatch_schedule_event(original, updated) do
    changed? =
      Enum.any?(@scheduling_fields, fn field ->
        Map.get(original, field) != Map.get(updated, field)
      end)

    if changed? do
      event =
        ProgramEvents.program_schedule_updated(updated.id, %{
          provider_id: updated.provider_id,
          meeting_days: updated.meeting_days,
          meeting_start_time: updated.meeting_start_time,
          meeting_end_time: updated.meeting_end_time,
          start_date: updated.start_date,
          end_date: updated.end_date
        })

      case DomainEventBus.dispatch(KlassHero.ProgramCatalog, event) do
        :ok ->
          :ok

        {:error, failures} ->
          Logger.warning("[UpdateProgram] Schedule event dispatch had failures",
            program_id: updated.id,
            errors: inspect(failures)
          )
      end
    end
  end
end
