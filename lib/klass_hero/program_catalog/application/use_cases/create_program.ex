defmodule KlassHero.ProgramCatalog.Application.UseCases.CreateProgram do
  @moduledoc """
  Use case for creating a new program.

  Orchestrates persistence and domain event publishing.
  Does NOT call Provider — the web layer is responsible for
  resolving instructor data before calling this use case.
  """

  alias KlassHero.ProgramCatalog.Domain.Events.ProgramEvents
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @repository Application.compile_env!(:klass_hero, [:program_catalog, :repository])

  def execute(attrs) when is_map(attrs) do
    attrs_with_id = Map.put_new(attrs, :id, Ecto.UUID.generate())

    with {:ok, program} <- @repository.create(attrs_with_id) do
      # Trigger: program successfully persisted
      # Why: downstream contexts may need to react (e.g., notifications)
      # Outcome: domain event dispatched to ProgramCatalog bus, then promoted to integration event
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

      {:ok, program}
    end
  end
end
