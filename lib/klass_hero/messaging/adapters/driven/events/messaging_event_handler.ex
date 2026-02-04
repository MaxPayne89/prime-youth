defmodule KlassHero.Messaging.Adapters.Driven.Events.MessagingEventHandler do
  @moduledoc """
  Event handler for the Messaging context.

  Listens to cross-context domain events and reacts accordingly:

  ## Subscribed Events

  - `:user_anonymized` - Anonymizes messaging data for the user:
    - Replaces message content with `"[deleted]"`
    - Marks all active conversation participations as left
    - Publishes `message_data_anonymized` integration event

  ## Error Handling

  Operations use retry logic with backoff for transient failures.
  Errors are returned as tuples for the EventSubscriber to log without blocking event processing.
  """

  @behaviour KlassHero.Shared.Domain.Ports.ForHandlingEvents

  alias KlassHero.Messaging
  alias KlassHero.Shared.Adapters.Driven.Events.RetryHelpers

  @impl true
  def subscribed_events, do: [:user_anonymized]

  @impl true
  def handle_event(%{event_type: :user_anonymized, aggregate_id: user_id}) do
    anonymize_messaging_data_with_retry(user_id)
  end

  def handle_event(_event), do: :ignore

  defp anonymize_messaging_data_with_retry(user_id) do
    operation = fn ->
      Messaging.anonymize_data_for_user(user_id)
    end

    context = %{
      operation_name: "anonymize messaging data",
      aggregate_id: user_id,
      backoff_ms: 100
    }

    # Trigger: RetryHelpers preserves {:ok, result} from the operation
    # Why: ForHandlingEvents contract specifies :ok | {:error, _} | :ignore,
    #   and EventSubscriber logs a warning for any value outside that set
    # Outcome: strip the result from {:ok, _} to return bare :ok
    case RetryHelpers.retry_with_backoff(operation, context) do
      {:ok, _} -> :ok
      other -> other
    end
  end
end
