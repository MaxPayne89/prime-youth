defmodule KlassHero.Messaging.IntegrationEventPublisher do
  @moduledoc """
  Convenience module for publishing Messaging context integration events.

  Provides thin wrappers around the generic integration event publishing
  infrastructure for messaging-related cross-context events.

  ## Usage

      alias KlassHero.Messaging.IntegrationEventPublisher

      # After anonymizing a user's messaging data
      IntegrationEventPublisher.publish_message_data_anonymized(user_id)
  """

  alias KlassHero.Messaging.Domain.Events.MessagingIntegrationEvents
  alias KlassHero.Shared.IntegrationEventPublishing

  @doc """
  Publishes a `message_data_anonymized` integration event.

  This is a critical event for GDPR compliance that should not be lost.
  Signals to downstream contexts that messaging data for this user has
  been anonymized.

  ## Parameters

  - `user_id` - The ID of the user whose messaging data was anonymized
  - `opts` - Metadata options (correlation_id, causation_id)

  ## Returns

  - `:ok` on successful publish
  - `{:error, reason}` on failure
  """
  # TODO: The :critical flag on this event has no delivery guarantee implementation yet.
  #   It is treated identically to :normal (fire-and-forget PubSub). Address on a
  #   dedicated branch when guaranteed delivery support is added.
  @spec publish_message_data_anonymized(binary(), keyword()) :: :ok | {:error, term()}
  def publish_message_data_anonymized(user_id, opts \\ []) when is_binary(user_id) do
    user_id
    |> MessagingIntegrationEvents.message_data_anonymized(%{}, opts)
    |> IntegrationEventPublishing.publish()
  end
end
