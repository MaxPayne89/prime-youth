defmodule KlassHero.Family.Domain.Events.FamilyIntegrationEvents do
  @moduledoc """
  Factory module for creating Family context integration events.

  Integration events are the public contract between bounded contexts.
  They carry stable, versioned payloads with only primitive types.

  ## Events

  - `:child_data_anonymized` - Emitted when a child's PII is anonymized during
    GDPR account deletion (critical). Downstream contexts (e.g. Participation)
    react to this event to anonymize their own child-related data.
  """

  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  @source_context :family
  @entity_type :child

  @doc """
  Creates a `child_data_anonymized` integration event.

  This event is marked as `:critical` by default since it is part of the
  GDPR deletion cascade and must not be lost.

  ## Parameters

  - `child_id` - The ID of the child whose data was anonymized
  - `payload` - Additional event-specific data
  - `opts` - Metadata options (correlation_id, causation_id)

  ## Payload Fields

  Standard payload includes:
  - `child_id` - The child's ID

  ## Raises

  - `ArgumentError` if `child_id` is nil or empty

  ## Examples

      iex> event = FamilyIntegrationEvents.child_data_anonymized("child-uuid")
      iex> event.event_type
      :child_data_anonymized
      iex> event.source_context
      :family
      iex> IntegrationEvent.critical?(event)
      true
  """
  def child_data_anonymized(child_id, payload \\ %{}, opts \\ [])

  def child_data_anonymized(child_id, payload, opts)
      when is_binary(child_id) and byte_size(child_id) > 0 do
    base_payload = %{child_id: child_id}

    opts = Keyword.put_new(opts, :criticality, :critical)

    IntegrationEvent.new(
      :child_data_anonymized,
      @source_context,
      @entity_type,
      child_id,
      # Trigger: caller may pass a conflicting :child_id in payload
      # Why: base_payload contains the canonical child_id from the function argument
      # Outcome: base_payload keys always win, preventing accidental overwrite
      Map.merge(payload, base_payload),
      opts
    )
  end

  def child_data_anonymized(child_id, _payload, _opts) do
    raise ArgumentError,
          "child_data_anonymized/3 requires a non-empty child_id string, got: #{inspect(child_id)}"
  end
end
