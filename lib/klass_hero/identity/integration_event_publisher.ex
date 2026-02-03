defmodule KlassHero.Identity.IntegrationEventPublisher do
  @moduledoc """
  Convenience module for publishing Identity context integration events.

  Provides thin wrappers around the generic integration event publishing
  infrastructure for identity-related cross-context events.

  ## Usage

      alias KlassHero.Identity.IntegrationEventPublisher

      # After anonymizing a child's data
      IntegrationEventPublisher.publish_child_data_anonymized(child_id)
  """

  alias KlassHero.Identity.Domain.Events.IdentityIntegrationEvents
  alias KlassHero.Shared.IntegrationEventPublishing

  @doc """
  Publishes a `child_data_anonymized` integration event.

  This is a critical event for GDPR compliance that should not be lost.
  Downstream contexts (e.g. Participation) react to anonymize their own
  child-related data.

  ## Parameters

  - `child_id` - The ID of the child whose data was anonymized
  - `opts` - Metadata options (correlation_id, causation_id)

  ## Returns

  - `:ok` on successful publish
  - `{:error, reason}` on failure
  """
  def publish_child_data_anonymized(child_id, opts \\ []) when is_binary(child_id) do
    child_id
    |> IdentityIntegrationEvents.child_data_anonymized(%{}, opts)
    |> IntegrationEventPublishing.publish()
  end
end
