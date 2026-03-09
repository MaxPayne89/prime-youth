defmodule KlassHero.Shared.IntegrationEventPublishing do
  @moduledoc """
  Shared utilities for integration event publishing across bounded contexts.

  This module provides a centralized way to access the configured integration
  event publisher, mirroring `EventPublishing` but for cross-context events.

  ## Configuration

  The publisher module is configured in application config:

      config :klass_hero, :integration_event_publisher,
        module: KlassHero.Shared.Adapters.Driven.Events.PubSubIntegrationEventPublisher,
        pubsub: KlassHero.PubSub

  For tests, configure a test publisher:

      config :klass_hero, :integration_event_publisher,
        module: KlassHero.Shared.Adapters.Driven.Events.TestIntegrationEventPublisher,
        pubsub: KlassHero.PubSub

  ## Usage

      alias KlassHero.Shared.IntegrationEventPublishing

      # Get the configured publisher module
      IntegrationEventPublishing.publisher_module()

      # Publish an integration event directly
      IntegrationEventPublishing.publish(event)
  """

  alias KlassHero.Shared.Adapters.Driven.Events.PubSubIntegrationEventPublisher

  require Logger

  @doc """
  Returns the configured integration event publisher module.

  Falls back to `PubSubIntegrationEventPublisher` if not configured.
  """
  @spec publisher_module() :: module()
  def publisher_module do
    :klass_hero
    |> Application.get_env(:integration_event_publisher, [])
    |> Keyword.get(:module, PubSubIntegrationEventPublisher)
  end

  @doc """
  Publishes an integration event using the configured publisher.

  ## Parameters

  - `event` - The integration event struct to publish

  ## Returns

  - `:ok` on successful publish
  - `{:error, reason}` on failure
  """
  @spec publish(struct()) :: :ok | {:error, term()}
  def publish(event) do
    publisher_module().publish(event)
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
