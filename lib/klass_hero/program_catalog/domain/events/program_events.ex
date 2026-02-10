defmodule KlassHero.ProgramCatalog.Domain.Events.ProgramEvents do
  @moduledoc """
  Factory module for creating Program domain events.

  ## Events

  - `:program_created` - Emitted when a provider creates a new program
  """

  alias KlassHero.Shared.Domain.Events.DomainEvent

  @aggregate_type :program

  def program_created(program_id, payload \\ %{}, opts \\ [])

  def program_created(program_id, payload, opts)
      when is_binary(program_id) and byte_size(program_id) > 0 do
    base_payload = %{program_id: program_id}

    DomainEvent.new(
      :program_created,
      program_id,
      @aggregate_type,
      Map.merge(base_payload, payload),
      opts
    )
  end

  def program_created(program_id, _payload, _opts) do
    raise ArgumentError,
          "program_created/3 requires a non-empty program_id string, got: #{inspect(program_id)}"
  end
end
