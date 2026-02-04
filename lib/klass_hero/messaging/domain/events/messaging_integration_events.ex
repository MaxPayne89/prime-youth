defmodule KlassHero.Messaging.Domain.Events.MessagingIntegrationEvents do
  @moduledoc """
  Factory module for creating Messaging context integration events.

  Integration events are the public contract between bounded contexts.
  They carry stable, versioned payloads with only primitive types.

  ## Events

  - `:message_data_anonymized` - Emitted when a user's messaging data is anonymized
    during GDPR account deletion (critical). Downstream contexts can react to
    confirm the messaging anonymization cascade is complete.
  """

  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  @source_context :messaging
  @entity_type :user

  @doc """
  Creates a `message_data_anonymized` integration event.

  This event is marked as `:critical` by default since it is part of the
  GDPR deletion cascade and must not be lost.

  ## Parameters

  - `user_id` - The ID of the user whose messaging data was anonymized
  - `payload` - Additional event-specific data
  - `opts` - Metadata options (correlation_id, causation_id)

  ## Payload Fields

  Standard payload includes:
  - `user_id` - The user's ID

  ## Raises

  - `ArgumentError` if `user_id` is nil or empty

  ## Examples

      iex> event = MessagingIntegrationEvents.message_data_anonymized("user-uuid")
      iex> event.event_type
      :message_data_anonymized
      iex> event.source_context
      :messaging
      iex> IntegrationEvent.critical?(event)
      true
  """
  def message_data_anonymized(user_id, payload \\ %{}, opts \\ [])

  def message_data_anonymized(user_id, payload, opts)
      when is_binary(user_id) and byte_size(user_id) > 0 do
    base_payload = %{user_id: user_id}

    opts = Keyword.put_new(opts, :criticality, :critical)

    IntegrationEvent.new(
      :message_data_anonymized,
      @source_context,
      @entity_type,
      user_id,
      # Trigger: caller may pass a conflicting :user_id in payload
      # Why: base_payload contains the canonical user_id from the function argument
      # Outcome: Map.merge/2 gives precedence to the second argument, so base_payload keys always win
      Map.merge(payload, base_payload),
      opts
    )
  end

  def message_data_anonymized(user_id, _payload, _opts) do
    raise ArgumentError,
          "message_data_anonymized requires a non-empty user_id string, got: #{inspect(user_id)}"
  end
end
