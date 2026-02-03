defmodule KlassHero.Identity.EventPublisher do
  @moduledoc """
  Convenience module for publishing Identity context domain events.

  Provides thin wrappers around the generic event publishing infrastructure
  for identity-related events.

  ## Usage

      alias KlassHero.Identity.EventPublisher

      # After anonymizing a child's data
      EventPublisher.publish_child_data_anonymized(child_id)
  """

  alias KlassHero.Identity.Domain.Events.IdentityEvents
  alias KlassHero.Shared.EventPublishing

  @doc """
  Publishes a `child_data_anonymized` event.

  This is a critical event for GDPR compliance that should not be lost.
  Downstream contexts (e.g. Participation) react to anonymize their own
  child-related data.

  ## Parameters

  - `child_id` - The ID of the child whose data was anonymized
  - `opts` - Metadata options (correlation_id, causation_id, user_id)

  ## Returns

  - `:ok` on successful publish
  - `{:error, reason}` on failure
  """
  def publish_child_data_anonymized(child_id, opts \\ []) when is_binary(child_id) do
    child_id
    |> IdentityEvents.child_data_anonymized(%{}, opts)
    |> EventPublishing.publish()
  end
end
