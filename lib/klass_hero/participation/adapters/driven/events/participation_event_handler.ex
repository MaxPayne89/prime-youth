defmodule KlassHero.Participation.Adapters.Driven.Events.ParticipationEventHandler do
  @moduledoc """
  Event handler for Participation context.

  Listens to cross-context domain events and triggers Participation-owned
  data operations in response.

  ## Subscribed Events

  - `:child_data_anonymized` - Anonymizes behavioral notes for the child:
    - Replaces note content with anonymized placeholder
    - Sets status to :rejected
    - Clears rejection reasons

  ## Error Handling

  Operations are handled with retry logic:
  - Transient errors → Retry once with backoff
  - Permanent errors → Log and return error
  """

  @behaviour KlassHero.Shared.Domain.Ports.ForHandlingEvents

  alias KlassHero.Participation
  alias KlassHero.Shared.Adapters.Driven.Events.RetryHelpers

  @impl true
  def subscribed_events, do: [:child_data_anonymized]

  @impl true
  def handle_event(%{event_type: :child_data_anonymized, aggregate_id: child_id}) do
    anonymize_notes_with_retry(child_id)
  end

  def handle_event(_event), do: :ignore

  defp anonymize_notes_with_retry(child_id) do
    operation = fn ->
      Participation.anonymize_behavioral_notes_for_child(child_id)
    end

    context = %{
      operation_name: "anonymize behavioral notes",
      aggregate_id: child_id,
      backoff_ms: 100
    }

    # Trigger: RetryHelpers passes through {:ok, count} but EventSubscriber expects bare :ok
    # Why: handler contract (ForHandlingEvents) returns :ok | {:error, _} | :ignore
    # Outcome: normalize {:ok, _} to :ok for the subscriber
    case RetryHelpers.retry_with_backoff(operation, context) do
      {:ok, _} -> :ok
      other -> other
    end
  end
end
