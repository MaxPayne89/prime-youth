defmodule KlassHero.Shared.Adapters.Driven.Events.CriticalEventHandlerRegistry do
  @moduledoc """
  Config-driven registry mapping integration event topics to handler modules.

  Used by `PubSubIntegrationEventPublisher` to look up which handlers need
  durable Oban-backed delivery for critical integration events. The mapping
  is defined in application config under `:critical_event_handlers`.

  Only critical event subscriptions are registered here. Non-critical events
  continue using `EventSubscriber` via PubSub only.
  """

  @doc """
  Returns handler `{module, function}` tuples for a given integration event topic.

  Returns an empty list if no handlers are configured for the topic.
  """
  @spec handlers_for(String.t()) :: [{module(), atom()}]
  def handlers_for(topic) when is_binary(topic) do
    :klass_hero
    |> Application.get_env(:critical_event_handlers, %{})
    |> Map.get(topic, [])
  end
end
