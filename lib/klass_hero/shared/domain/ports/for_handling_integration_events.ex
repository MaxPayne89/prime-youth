defmodule KlassHero.Shared.Domain.Ports.ForHandlingIntegrationEvents do
  @moduledoc """
  Behaviour for integration event handlers.

  Implement this behaviour to create handlers that react to integration
  events from other bounded contexts. Integration events are the public
  contract between contexts — they carry stable, versioned payloads.

  ## Example

      defmodule MyApp.Participation.ChildAnonymizedHandler do
        @behaviour KlassHero.Shared.Domain.Ports.ForHandlingIntegrationEvents

        @impl true
        def subscribed_events, do: [:child_data_anonymized]

        @impl true
        def handle_event(%IntegrationEvent{event_type: :child_data_anonymized} = event) do
          # Anonymize participation data for child
          :ok
        end

        def handle_event(_event), do: :ignore
      end
  """

  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  @doc """
  Handles an integration event.

  Returns:
  - `:ok` - Event handled successfully
  - `{:error, reason}` - Handling failed (will be logged)
  - `:ignore` - Event was intentionally ignored
  """
  @callback handle_event(IntegrationEvent.t()) :: :ok | {:error, term()} | :ignore

  @doc """
  Returns the list of event types this handler subscribes to.

  Return `[:all]` to receive all events (use sparingly).
  """
  @callback subscribed_events() :: [atom()] | [:all]
end
