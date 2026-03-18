defmodule KlassHero.Shared.IntegrationEventPublishing do
  @moduledoc """
  Shared utilities for integration event publishing across bounded contexts.

  The publisher module is resolved at runtime from application config to allow
  the invite-claim saga test to swap to the real PubSub publisher.

      config :klass_hero, :integration_event_publisher,
        module: KlassHero.Shared.Adapters.Driven.Events.PubSubIntegrationEventPublisher,
        pubsub: KlassHero.PubSub

  ## Usage

      IntegrationEventPublishing.publish(event)
      IntegrationEventPublishing.publish_critical(event, "label")
      IntegrationEventPublishing.publish_best_effort(event, "label")
  """

  require Logger

  @doc """
  Publishes an integration event using the configured publisher.

  Returns `:ok` on success, `{:error, reason}` on failure.
  """
  @spec publish(struct()) :: :ok | {:error, term()}
  def publish(event), do: publisher_module().publish(event)

  defp publisher_module do
    Application.get_env(:klass_hero, :integration_event_publisher)[:module]
  end

  @doc """
  Publishes an integration event and propagates failures.

  Logs a warning on failure with the given label and metadata fields,
  then returns the `{:error, reason}` tuple so the caller can react.

  ## Parameters

  - `event` - The integration event struct to publish
  - `label` - Event name for the log message (e.g. `"program_created"`)
  - `log_fields` - Extra keyword metadata for the log entry (default: `[]`)
  """
  @spec publish_critical(struct(), String.t(), keyword()) :: :ok | {:error, term()}
  def publish_critical(event, label, log_fields \\ []) do
    case publish(event) do
      :ok ->
        :ok

      {:error, reason} = error ->
        Logger.warning(
          "[PromoteIntegrationEvents] Failed to publish #{label}",
          Keyword.put(log_fields, :reason, inspect(reason))
        )

        error
    end
  end

  @doc """
  Publishes an integration event, swallowing failures.

  Logs a warning on failure with the given label and metadata fields,
  but always returns `:ok`. Use for non-critical notifications where
  the underlying state change is already durable.

  ## Parameters

  - `event` - The integration event struct to publish
  - `label` - Event name for the log message (e.g. `"messages_read"`)
  - `log_fields` - Extra keyword metadata for the log entry (default: `[]`)
  """
  @spec publish_best_effort(struct(), String.t(), keyword()) :: :ok
  def publish_best_effort(event, label, log_fields \\ []) do
    case publish(event) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "[PromoteIntegrationEvents] Failed to publish #{label}",
          Keyword.put(log_fields, :reason, inspect(reason))
        )

        :ok
    end
  end
end
