defmodule KlassHero.Participation.EventPublisher do
  @moduledoc """
  Event publishing wrapper for the Participation context.

  Delegates to the shared event publishing infrastructure.
  """

  alias KlassHero.Shared.EventPublishing

  @doc """
  Publishes a domain event.

  The event will be published to a topic based on its aggregate type and event type.
  """
  @spec publish(map()) :: :ok | {:error, term()}
  def publish(event) do
    EventPublishing.publish(event)
  end
end
