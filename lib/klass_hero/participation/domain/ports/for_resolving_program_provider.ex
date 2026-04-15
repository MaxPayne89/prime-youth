defmodule KlassHero.Participation.Domain.Ports.ForResolvingProgramProvider do
  @moduledoc """
  Port for resolving program ownership from ProgramCatalog context.

  ## Anti-Corruption Layer

  This port defines the contract for an anti-corruption layer between the
  Participation bounded context and the ProgramCatalog bounded context.

  The Participation context needs provider IDs to route domain events to
  provider-specific PubSub topics. This port isolates the cross-context
  lookup behind a behaviour contract.

  ## Error Mapping

  ProgramCatalog errors are mapped to Participation semantics:
  - Program not found → `:program_not_found`
  """

  @doc """
  Resolves the provider ID that owns the given program.

  Returns `{:ok, provider_id}` or `{:error, :program_not_found}`.
  """
  @callback resolve_provider_id(program_id :: binary()) ::
              {:ok, binary()} | {:error, :program_not_found}

  @doc """
  Resolves provider details (provider_id and program_title) for a given program.

  Returns `{:ok, %{provider_id: binary(), program_title: binary()}}` or
  `{:error, :program_not_found}`.
  """
  @callback resolve_provider_details(program_id :: binary()) ::
              {:ok, %{provider_id: binary(), program_title: binary()}} | {:error, :program_not_found}
end
