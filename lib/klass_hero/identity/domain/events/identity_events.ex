defmodule KlassHero.Identity.Domain.Events.IdentityEvents do
  @moduledoc """
  Factory module for creating Identity domain events.

  Provides convenience functions to create standardized DomainEvent structs
  for identity-related events.

  ## Events

  - `:child_data_anonymized` - Emitted when a child's PII is anonymized during
    GDPR account deletion (critical). Downstream contexts (e.g. Participation)
    react to this event to anonymize their own child-related data.
  """

  alias KlassHero.Shared.Domain.Events.DomainEvent

  @aggregate_type :child

  @doc """
  Creates a `child_data_anonymized` event.

  This event is marked as `:critical` by default since it is part of the
  GDPR deletion cascade and must not be lost.

  ## Parameters

  - `child_id` - The ID of the child whose data was anonymized
  - `payload` - Additional event-specific data
  - `opts` - Metadata options (correlation_id, causation_id, user_id)

  ## Payload Fields

  Standard payload includes:
  - `child_id` - The child's ID

  ## Raises

  - `ArgumentError` if `child_id` is nil or empty

  ## Examples

      iex> event = IdentityEvents.child_data_anonymized("child-uuid")
      iex> event.event_type
      :child_data_anonymized
      iex> DomainEvent.critical?(event)
      true
  """
  def child_data_anonymized(child_id, payload \\ %{}, opts \\ [])

  def child_data_anonymized(child_id, payload, opts)
      when is_binary(child_id) and byte_size(child_id) > 0 do
    base_payload = %{child_id: child_id}

    opts = Keyword.put_new(opts, :criticality, :critical)

    DomainEvent.new(
      :child_data_anonymized,
      child_id,
      @aggregate_type,
      Map.merge(base_payload, payload),
      opts
    )
  end

  def child_data_anonymized(child_id, _payload, _opts) do
    raise ArgumentError,
          "child_data_anonymized/3 requires a non-empty child_id string, got: #{inspect(child_id)}"
  end
end
