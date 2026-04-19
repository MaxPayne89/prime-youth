defmodule KlassHero.Participation.Adapters.Driving.Events.EventHandlers.PromoteIntegrationEvents do
  @moduledoc """
  Promotes Participation domain events to integration events for cross-context communication.

  Registered on the Participation DomainEventBus. When a relevant domain event is
  dispatched, this handler creates the corresponding integration event and
  publishes it via PubSub.

  ## Error strategy

  All events are **best-effort**: the underlying state change is already durable,
  so the integration event is a notification, not a guarantee. Publish failures
  are swallowed and return `:ok`.
  """

  alias KlassHero.Participation.Domain.Events.ParticipationIntegrationEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.IntegrationEventPublishing

  @doc """
  Handles a domain event by promoting it to the corresponding integration event.
  """
  @spec handle(DomainEvent.t()) :: :ok

  # ---------------------------------------------------------------------------
  # Session lifecycle events
  # ---------------------------------------------------------------------------

  def handle(%DomainEvent{event_type: :session_created} = event) do
    # Trigger: session_created domain event dispatched from CreateSession use case
    # Why: downstream contexts need to know about new sessions (scheduling, notifications)
    # Outcome: best-effort publish; swallow failures since session is already persisted
    ParticipationIntegrationEvents.session_created(event.aggregate_id, event.payload)
    |> IntegrationEventPublishing.publish_best_effort("session_created",
      session_id: event.aggregate_id
    )
  end

  def handle(%DomainEvent{event_type: :session_started} = event) do
    # Trigger: session_started domain event dispatched when instructor opens a session
    # Why: downstream contexts may react to session starting (real-time dashboards, notifications)
    # Outcome: best-effort publish; swallow failures since session state is already updated
    ParticipationIntegrationEvents.session_started(event.aggregate_id, event.payload)
    |> IntegrationEventPublishing.publish_best_effort("session_started",
      session_id: event.aggregate_id
    )
  end

  def handle(%DomainEvent{event_type: :session_completed} = event) do
    # Trigger: session_completed domain event dispatched when all check-outs are done
    # Why: downstream contexts may react to session ending (progress tracking, billing)
    # Outcome: best-effort publish; swallow failures since session state is already updated
    ParticipationIntegrationEvents.session_completed(event.aggregate_id, event.payload)
    |> IntegrationEventPublishing.publish_best_effort("session_completed",
      session_id: event.aggregate_id
    )
  end

  def handle(%DomainEvent{event_type: :session_cancelled} = event) do
    # Trigger: session_cancelled domain event dispatched when a session is cancelled
    # Why: downstream projections (e.g. ProviderSessionDetails) must mark it cancelled
    # Outcome: best-effort publish; swallow failures since cancellation is already persisted
    ParticipationIntegrationEvents.session_cancelled(event.aggregate_id, event.payload)
    |> IntegrationEventPublishing.publish_best_effort("session_cancelled",
      session_id: event.aggregate_id
    )
  end

  def handle(%DomainEvent{event_type: :roster_seeded} = event) do
    # Trigger: roster_seeded domain event dispatched from SeedSessionRoster use case
    # Why: downstream contexts may need to know roster is ready (e.g. notifications)
    # Outcome: best-effort publish; swallow failures since records are already persisted
    ParticipationIntegrationEvents.roster_seeded(event.aggregate_id, event.payload)
    |> IntegrationEventPublishing.publish_best_effort("roster_seeded",
      session_id: event.aggregate_id
    )
  end

  # ---------------------------------------------------------------------------
  # Attendance events
  # ---------------------------------------------------------------------------

  def handle(%DomainEvent{event_type: :child_checked_in} = event) do
    # Trigger: child_checked_in domain event dispatched from CheckIn use case
    # Why: downstream contexts need attendance data (family notifications, progress tracking)
    # Outcome: best-effort publish; swallow failures since check-in is already recorded
    ParticipationIntegrationEvents.child_checked_in(event.aggregate_id, event.payload)
    |> IntegrationEventPublishing.publish_best_effort("child_checked_in",
      record_id: event.aggregate_id
    )
  end

  def handle(%DomainEvent{event_type: :child_checked_out} = event) do
    # Trigger: child_checked_out domain event dispatched from CheckOut use case
    # Why: downstream contexts need check-out data (family notifications, billing duration)
    # Outcome: best-effort publish; swallow failures since check-out is already recorded
    ParticipationIntegrationEvents.child_checked_out(event.aggregate_id, event.payload)
    |> IntegrationEventPublishing.publish_best_effort("child_checked_out",
      record_id: event.aggregate_id
    )
  end

  def handle(%DomainEvent{event_type: :child_marked_absent} = event) do
    # Trigger: child_marked_absent domain event dispatched from MarkAbsent use case
    # Why: downstream contexts need absence data (family notifications, attendance reports)
    # Outcome: best-effort publish; swallow failures since absence is already recorded
    ParticipationIntegrationEvents.child_marked_absent(event.aggregate_id, event.payload)
    |> IntegrationEventPublishing.publish_best_effort("child_marked_absent",
      record_id: event.aggregate_id
    )
  end

  # ---------------------------------------------------------------------------
  # Behavioral note events
  # ---------------------------------------------------------------------------

  def handle(%DomainEvent{event_type: :behavioral_note_submitted} = event) do
    # Trigger: behavioral_note_submitted domain event dispatched from SubmitNote use case
    # Why: downstream contexts need to know about pending notes (parent notifications)
    # Outcome: best-effort publish; swallow failures since note is already persisted
    ParticipationIntegrationEvents.behavioral_note_submitted(event.aggregate_id, event.payload)
    |> IntegrationEventPublishing.publish_best_effort("behavioral_note_submitted",
      note_id: event.aggregate_id
    )
  end

  def handle(%DomainEvent{event_type: :behavioral_note_approved} = event) do
    # Trigger: behavioral_note_approved domain event dispatched from ApproveNote use case
    # Why: downstream contexts need approval status (provider dashboards, progress tracking)
    # Outcome: best-effort publish; swallow failures since approval is already persisted
    ParticipationIntegrationEvents.behavioral_note_approved(event.aggregate_id, event.payload)
    |> IntegrationEventPublishing.publish_best_effort("behavioral_note_approved",
      note_id: event.aggregate_id
    )
  end

  def handle(%DomainEvent{event_type: :behavioral_note_rejected} = event) do
    # Trigger: behavioral_note_rejected domain event dispatched from RejectNote use case
    # Why: downstream contexts need rejection status (provider dashboards, re-submission flow)
    # Outcome: best-effort publish; swallow failures since rejection is already persisted
    ParticipationIntegrationEvents.behavioral_note_rejected(event.aggregate_id, event.payload)
    |> IntegrationEventPublishing.publish_best_effort("behavioral_note_rejected",
      note_id: event.aggregate_id
    )
  end
end
