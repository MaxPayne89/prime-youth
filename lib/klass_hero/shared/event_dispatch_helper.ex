defmodule KlassHero.Shared.EventDispatchHelper do
  @moduledoc """
  Fire-and-forget event dispatch with criticality-aware logging.

  Wraps `DomainEventBus.dispatch/2` so callers never need to handle
  dispatch failures — the helper logs at the appropriate level based
  on event criticality and always returns `:ok`.
  """

  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @doc """
  Dispatches a domain event and logs failures at the appropriate level.

  - Critical events log at `:error` level on failure
  - Normal events log at `:warning` level on failure

  Always returns `:ok` — dispatch failures never propagate to callers.

  Argument order is event-first for clean piping:

      UserEvents.user_registered(user)
      |> EventDispatchHelper.dispatch(KlassHero.Accounts)
  """
  @spec dispatch(DomainEvent.t(), module()) :: :ok
  def dispatch(%DomainEvent{} = event, context) do
    case DomainEventBus.dispatch(context, event) do
      :ok ->
        :ok

      {:error, failures} ->
        log_dispatch_failure(event, failures)
        :ok
    end
  end

  # Trigger: critical events (e.g. GDPR anonymization) fail to dispatch
  # Why: critical events represent business-critical data that must not be silently lost
  # Outcome: error-level log ensures alerting systems catch the failure
  defp log_dispatch_failure(%DomainEvent{} = event, failures) do
    if DomainEvent.critical?(event) do
      Logger.error(
        "Critical event dispatch failed: event_type=#{event.event_type} failures=#{inspect(failures)}"
      )
    else
      Logger.warning(
        "Event dispatch failed: event_type=#{event.event_type} failures=#{inspect(failures)}"
      )
    end
  end
end
