defmodule KlassHero.Participation.Adapters.Driven.ProgramCatalogContext.ProgramProviderResolver do
  @moduledoc """
  Adapter for resolving program ownership from ProgramCatalog context.

  ## Anti-Corruption Layer

  This adapter serves as an anti-corruption layer between the Participation and
  ProgramCatalog bounded contexts. It resolves which provider owns a given program.

  ```
  NotifyLiveViews Handler → ForResolvingProgramProvider Port → [THIS ADAPTER] → ProgramCatalog Public API
       (needs provider_id)    (behaviour contract)              (ACL lookup)      (owns Program model)
  ```

  ## Error Mapping

  ProgramCatalog errors are mapped to Participation semantics:
  - Empty result from `get_programs_by_ids/1` → `:program_not_found`
  """

  @behaviour KlassHero.Participation.Domain.Ports.ForResolvingProgramProvider

  alias KlassHero.ProgramCatalog

  require Logger

  @impl true
  def resolve_provider_id(program_id) when is_binary(program_id) do
    case ProgramCatalog.get_programs_by_ids([program_id]) do
      [program] -> {:ok, program.provider_id}
      _other -> {:error, :program_not_found}
    end
  rescue
    error ->
      Logger.warning("[ProgramProviderResolver] Failed to resolve provider",
        program_id: program_id,
        error: Exception.message(error)
      )

      {:error, :program_not_found}
  end

  @impl true
  def resolve_provider_details(program_id) when is_binary(program_id) do
    case ProgramCatalog.get_programs_by_ids([program_id]) do
      [program] ->
        {:ok, %{provider_id: program.provider_id, program_title: program.title}}

      _other ->
        {:error, :program_not_found}
    end
  rescue
    error ->
      Logger.warning("[ProgramProviderResolver] Failed to resolve provider details",
        program_id: program_id,
        error: Exception.message(error)
      )

      {:error, :program_not_found}
  end
end
