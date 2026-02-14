defmodule KlassHero.ProgramCatalog.Application.UseCases.CreateProgram do
  @moduledoc """
  Use case for creating a new program.

  Orchestrates domain validation and persistence:
  1. Builds and validates the Program aggregate via Program.create/1
  2. Persists via the repository adapter
  3. Dispatches domain events on success
  """

  alias KlassHero.ProgramCatalog.Domain.Events.ProgramEvents
  alias KlassHero.ProgramCatalog.Domain.Models.Program
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @repository Application.compile_env!(:klass_hero, [:program_catalog, :repository])

  def execute(attrs) when is_map(attrs) do
    with {:ok, program} <- Program.create(attrs),
         {:ok, persisted} <- @repository.create(program) do
      dispatch_event(persisted)
      {:ok, persisted}
    end
  end

  defp dispatch_event(program) do
    event =
      ProgramEvents.program_created(program.id, %{
        provider_id: program.provider_id,
        title: program.title,
        category: program.category,
        instructor_id: program.instructor && program.instructor.id
      })

    case DomainEventBus.dispatch(KlassHero.ProgramCatalog, event) do
      :ok ->
        :ok

      {:error, failures} ->
        Logger.warning("[CreateProgram] Event dispatch had failures",
          program_id: program.id,
          errors: inspect(failures)
        )
    end
  end
end
