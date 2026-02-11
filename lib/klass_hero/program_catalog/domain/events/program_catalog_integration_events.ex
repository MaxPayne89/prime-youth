defmodule KlassHero.ProgramCatalog.Domain.Events.ProgramCatalogIntegrationEvents do
  @moduledoc """
  Factory module for creating ProgramCatalog integration events.

  Integration events are the public contract between bounded contexts.

  ## Events

  - `:program_created` - Emitted when a new program is created.
    Downstream contexts can react (e.g., notifications).
  """

  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  @source_context :program_catalog
  @entity_type :program

  def program_created(program_id, payload \\ %{}, opts \\ [])

  def program_created(program_id, payload, opts)
      when is_binary(program_id) and byte_size(program_id) > 0 do
    base_payload = %{program_id: program_id}

    IntegrationEvent.new(
      :program_created,
      @source_context,
      @entity_type,
      program_id,
      # Trigger: caller may pass a conflicting :program_id in payload
      # Why: base_payload contains the canonical program_id from the function argument
      # Outcome: base_payload keys always win, preventing accidental overwrite
      Map.merge(payload, base_payload),
      opts
    )
  end

  def program_created(program_id, _payload, _opts) do
    raise ArgumentError,
          "program_created/3 requires a non-empty program_id string, got: #{inspect(program_id)}"
  end
end
