defmodule KlassHero.Accounts.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents do
  @moduledoc """
  Promotes Accounts domain events to integration events for cross-context communication.

  Registered on the Accounts DomainEventBus. When a relevant domain event is
  dispatched, this handler creates the corresponding integration event and
  publishes it via PubSub.

  ## Error strategy

  Propagates publish failures — Identity profile creation depends on user_registered,
  and the GDPR anonymization cascade depends on user_anonymized.
  """

  alias KlassHero.Accounts.Domain.Events.AccountsIntegrationEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.IntegrationEventPublishing

  @doc """
  Handles a domain event by promoting it to the corresponding integration event.
  """
  @spec handle(DomainEvent.t()) :: :ok | {:error, term()}
  def handle(%DomainEvent{event_type: :user_registered} = event) do
    # Trigger: user_registered domain event dispatched from accounts.ex
    # Why: Identity context needs this to auto-create parent/provider profiles
    # Outcome: publish integration event; propagate failure so caller knows
    event.aggregate_id
    |> AccountsIntegrationEvents.user_registered(event.payload)
    |> IntegrationEventPublishing.publish()
  end

  def handle(%DomainEvent{event_type: :user_anonymized} = event) do
    # Trigger: user_anonymized domain event dispatched from accounts.ex
    # Why: Identity and Messaging must anonymize their own data (GDPR cascade)
    # Outcome: publish integration event; propagate failure to halt cascade on error
    event.aggregate_id
    |> AccountsIntegrationEvents.user_anonymized(event.payload)
    |> IntegrationEventPublishing.publish()
  end
end
