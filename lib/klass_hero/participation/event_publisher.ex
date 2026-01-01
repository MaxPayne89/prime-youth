defmodule KlassHero.Participation.EventPublisher do
  @moduledoc """
  Event publishing wrapper for the Participation context.

  Delegates to the configured event publisher implementation.
  """

  @doc """
  Publishes a domain event.

  The event will be published to a topic based on its aggregate type and event type.
  """
  @spec publish(map()) :: :ok | {:error, term()}
  def publish(event) do
    publisher_module().publish(event)
  end

  defp publisher_module do
    Application.get_env(:klass_hero, :event_publisher)[:module]
  end
end
