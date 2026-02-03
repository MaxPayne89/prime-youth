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
end
