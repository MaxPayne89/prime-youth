defmodule KlassHero.ProgramCatalog.Domain.Events.ProgramEvents do
  @moduledoc """
  Factory module for creating Program domain events.

  ## Events

  - `:program_created` - Emitted when a provider creates a new program
  - `:program_schedule_updated` - Emitted when scheduling fields change on an existing program
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

  def program_schedule_updated(program_id, payload \\ %{}, opts \\ [])

  def program_schedule_updated(program_id, payload, opts)
      when is_binary(program_id) and byte_size(program_id) > 0 do
    base_payload = %{program_id: program_id}

    DomainEvent.new(
      :program_schedule_updated,
      program_id,
      @aggregate_type,
      # Trigger: caller may pass a conflicting :program_id in payload
      # Why: base_payload contains the canonical program_id from the function argument
      # Outcome: base_payload keys always win, preventing accidental overwrite
      Map.merge(payload, base_payload),
      opts
    )
  end

  def program_schedule_updated(program_id, _payload, _opts) do
    raise ArgumentError,
          "program_schedule_updated/3 requires a non-empty program_id string, got: #{inspect(program_id)}"
  end
end
