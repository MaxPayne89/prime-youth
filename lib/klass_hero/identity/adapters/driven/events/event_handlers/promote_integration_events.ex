defmodule KlassHero.Identity.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents do
  @moduledoc """
  Promotes Identity domain events to integration events for cross-context communication.

  Registered on the Identity DomainEventBus. When a relevant domain event is
  dispatched, this handler creates the corresponding integration event and
  publishes it via PubSub.

  ## Error strategy

  Propagates publish failures — the GDPR anonymization cascade requires
  confirmation that downstream contexts were notified. A publish failure
  halts the reduce_while loop in the Identity facade.
  """

  alias KlassHero.Identity.Domain.Events.IdentityIntegrationEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.IntegrationEventPublishing

  @doc """
  Handles a domain event by promoting it to the corresponding integration event.
  """
  @spec handle(DomainEvent.t()) :: :ok | {:error, term()}
  def handle(%DomainEvent{event_type: :child_data_anonymized} = event) do
    child_id = event.payload.child_id

    # Trigger: child data anonymized domain event received
    # Why: downstream contexts (e.g. Participation) need to anonymize their own child data
    # Outcome: publish integration event; propagate failure to halt GDPR cascade on error
    child_id
    |> IdentityIntegrationEvents.child_data_anonymized()
    |> IntegrationEventPublishing.publish()
  end
end
