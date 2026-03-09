defmodule KlassHero.ProgramCatalog.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents do
  @moduledoc """
  Promotes ProgramCatalog domain events to integration events for cross-context communication.

  Registered on the ProgramCatalog DomainEventBus at priority 10.
  """

  alias KlassHero.ProgramCatalog.Domain.Events.ProgramCatalogIntegrationEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.IntegrationEventPublishing

  @spec handle(DomainEvent.t()) :: :ok | {:error, term()}
  def handle(%DomainEvent{event_type: :program_created} = event) do
    # Trigger: program_created domain event dispatched from CreateProgram use case
    # Why: other contexts may need to react to new programs
    # Outcome: publish integration event on PubSub topic integration:program_catalog:program_created
    event.aggregate_id
    |> ProgramCatalogIntegrationEvents.program_created(event.payload)
    |> IntegrationEventPublishing.publish_critical("program_created",
      program_id: event.aggregate_id
    )
  end

  def handle(%DomainEvent{event_type: :program_updated} = event) do
    # Trigger: program_updated domain event dispatched from UpdateProgram use case
    # Why: other contexts may need to react to program changes (e.g., refresh read models)
    # Outcome: publish integration event on PubSub topic integration:program_catalog:program_updated
    event.aggregate_id
    |> ProgramCatalogIntegrationEvents.program_updated(event.payload)
    |> IntegrationEventPublishing.publish_critical("program_updated",
      program_id: event.aggregate_id
    )
  end
end
