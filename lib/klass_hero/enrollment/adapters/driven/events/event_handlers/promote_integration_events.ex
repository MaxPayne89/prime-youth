defmodule KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents do
  @moduledoc """
  Promotes Enrollment domain events to integration events for cross-context communication.

  Registered on the Enrollment DomainEventBus at priority 10.
  """

  alias KlassHero.Enrollment.Domain.Events.EnrollmentIntegrationEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.IntegrationEventPublishing

  @spec handle(DomainEvent.t()) :: :ok | {:error, term()}
  def handle(%DomainEvent{event_type: :participant_policy_set} = event) do
    # Trigger: participant_policy_set domain event dispatched from SetParticipantPolicy use case
    # Why: other contexts may need to react to policy changes (e.g., search filtering)
    # Outcome: publish integration event on topic integration:enrollment:participant_policy_set
    event.aggregate_id
    |> EnrollmentIntegrationEvents.participant_policy_set(event.payload)
    |> IntegrationEventPublishing.publish_critical("participant_policy_set",
      program_id: event.aggregate_id
    )
  end

  def handle(%DomainEvent{event_type: :invite_claimed} = event) do
    # Trigger: invite_claimed domain event dispatched when a guardian claims an invite link
    # Why: downstream contexts (Family, Accounts) need to react — create profiles, link users
    # Outcome: publish integration event on topic integration:enrollment:invite_claimed
    event.payload.invite_id
    |> EnrollmentIntegrationEvents.invite_claimed(event.payload)
    |> IntegrationEventPublishing.publish_critical("invite_claimed",
      invite_id: event.payload.invite_id
    )
  end

  def handle(%DomainEvent{event_type: :enrollment_cancelled} = event) do
    # Trigger: enrollment_cancelled domain event dispatched from CancelEnrollmentByAdmin use case
    # Why: downstream contexts may react to cancellations (e.g., notifications, analytics)
    # Outcome: publish integration event on topic integration:enrollment:enrollment_cancelled
    event.payload.enrollment_id
    |> EnrollmentIntegrationEvents.enrollment_cancelled(event.payload)
    |> IntegrationEventPublishing.publish_critical("enrollment_cancelled",
      enrollment_id: event.payload.enrollment_id
    )
  end
end
