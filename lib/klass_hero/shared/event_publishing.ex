defmodule KlassHero.Shared.EventPublishing do
  @moduledoc """
  Shared utilities for event publishing across bounded contexts.

  This module provides a centralized way to access the configured event publisher,
  eliminating duplicate `publisher_module/0` implementations across contexts.

  ## Configuration

  The publisher module is configured in application config:

      config :klass_hero, :event_publisher,
        module: KlassHero.Shared.Adapters.Driven.Events.PubSubEventPublisher,
        pubsub: KlassHero.PubSub

  For tests, configure a test publisher:

      config :klass_hero, :event_publisher,
        module: KlassHero.Shared.Adapters.Driven.Events.TestEventPublisher,
        pubsub: KlassHero.PubSub

  ## Usage

      alias KlassHero.Shared.EventPublishing

      # Get the configured publisher module
      EventPublishing.publisher_module()

      # Publish an event directly
      EventPublishing.publish(event)
  """

  alias KlassHero.Shared.Adapters.Driven.Events.PubSubEventPublisher

  @doc """
  Returns the configured event publisher module.

  Falls back to `PubSubEventPublisher` if not configured.
  """
  @spec publisher_module() :: module()
  def publisher_module do
    :klass_hero
    |> Application.get_env(:event_publisher, [])
    |> Keyword.get(:module, PubSubEventPublisher)
  end

  @doc """
  Publishes an event using the configured publisher.

  ## Parameters

  - `event` - The domain event struct to publish

  ## Returns

  - `:ok` on successful publish
  - `{:error, reason}` on failure
  """
  @spec publish(struct()) :: :ok | {:error, term()}
  def publish(event) do
    publisher_module().publish(event)
  end
end
