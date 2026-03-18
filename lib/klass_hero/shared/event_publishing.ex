defmodule KlassHero.Shared.EventPublishing do
  @moduledoc """
  Shared utilities for domain event publishing across bounded contexts.

  The publisher module is resolved at compile time from application config:

      config :klass_hero, :event_publisher,
        module: KlassHero.Shared.Adapters.Driven.Events.PubSubEventPublisher,
        pubsub: KlassHero.PubSub

  ## Usage

      EventPublishing.publish(event)
      EventPublishing.publish(event, topic)
  """

  @publisher Application.compile_env!(:klass_hero, [:event_publisher, :module])

  @doc """
  Publishes an event using the configured publisher.

  Returns `:ok` on success, `{:error, reason}` on failure.
  """
  @spec publish(struct()) :: :ok | {:error, term()}
  def publish(event), do: @publisher.publish(event)

  @doc """
  Publishes an event to a specific topic using the configured publisher.

  Returns `:ok` on success, `{:error, reason}` on failure.
  """
  @spec publish(struct(), String.t()) :: :ok | {:error, term()}
  def publish(event, topic), do: @publisher.publish(event, topic)
end
