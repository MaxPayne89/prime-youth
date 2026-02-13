defmodule KlassHero.Shared do
  @moduledoc """
  Shared kernel — cross-cutting utilities used by all bounded contexts.

  Contains domain event infrastructure, error IDs, storage adapters,
  and common domain types.
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Categories,
      ErrorIds,
      SubscriptionTiers,
      Domain.Events.DomainEvent,
      Domain.Events.IntegrationEvent,
      Domain.Ports.ForHandlingEvents,
      Domain.Ports.ForHandlingIntegrationEvents,
      Domain.Services.ActivityGoalCalculator,
      Domain.Types.Pagination.PageResult,
      DomainEventBus,
      EventPublishing,
      IntegrationEventPublishing,
      EventDispatchHelper,
      Adapters.Driven.Events.RetryHelpers,
      Adapters.Driven.Persistence.EctoErrorHelpers,
      Storage
    ]
end
