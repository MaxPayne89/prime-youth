defmodule KlassHero.Shared.EventDispatchHelper do
  @moduledoc """
  Fire-and-forget event dispatch with criticality-aware logging and
  durable delivery for critical events.

  Wraps `DomainEventBus.dispatch/2` so callers never need to handle
  dispatch failures — the helper logs at the appropriate level based
  on event criticality and always returns `:ok`.

  For critical events, failed handlers are automatically retried via Oban.
  """

  alias KlassHero.Shared.Adapters.Driven.Events.CriticalEventSerializer
  alias KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorker
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.Domain.Services.CriticalEventDispatcher
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @doc """
  Dispatches a domain event and logs failures at the appropriate level.

  For critical events:
  - Uses `DomainEventBus.dispatch_critical/2` to get per-handler results
  - Marks successful handlers as processed (idempotency gate)
  - Enqueues Oban retry jobs for failed handlers

  For normal events:
  - Uses `DomainEventBus.dispatch/2` (fire-and-forget, unchanged)

  Always returns `:ok` — dispatch failures never propagate to callers.

  Argument order is event-first for clean piping:

      UserEvents.user_registered(user)
      |> EventDispatchHelper.dispatch(KlassHero.Accounts)
  """
  @spec dispatch(DomainEvent.t(), module()) :: :ok
  def dispatch(%DomainEvent{} = event, context) do
    if DomainEvent.critical?(event) do
      dispatch_critical(event, context)
    else
      dispatch_normal(event, context)
    end
  end

  @doc """
  Dispatches a domain event and propagates the first handler failure.

  Unlike `dispatch/2` (fire-and-forget), this variant returns `{:error, reason}`
  when any handler fails — useful in `with` chains where dispatch failure must
  halt the pipeline.

  For critical events, this does NOT enqueue Oban jobs. The caller owns error
  handling — they receive `{:error, reason}` and can roll back their own
  transaction. Enqueueing a retry would conflict with the caller's rollback.

      FamilyEvents.invite_family_ready(invite_id, payload)
      |> EventDispatchHelper.dispatch_or_error(KlassHero.Family)
  """
  @spec dispatch_or_error(DomainEvent.t(), module()) :: :ok | {:error, term()}
  def dispatch_or_error(%DomainEvent{} = event, context) do
    if DomainEvent.critical?(event) do
      {:ok, results} = DomainEventBus.dispatch_critical(context, event)

      case Enum.find(results, fn {_identity, result} -> match?({:error, _}, result) end) do
        nil -> :ok
        {_identity, {:error, reason}} -> {:error, reason}
      end
    else
      case DomainEventBus.dispatch(context, event) do
        :ok -> :ok
        {:error, [first_failure | _]} -> normalize_failure(first_failure)
      end
    end
  end

  # -- Critical event dispatch --

  # Trigger: event has criticality: :critical
  # Why: critical events must not be silently lost — failed handlers get Oban retry
  # Outcome: successful handlers marked as processed, failed handlers enqueued for retry
  defp dispatch_critical(%DomainEvent{} = event, context) do
    {:ok, results} = DomainEventBus.dispatch_critical(context, event)

    Enum.each(results, fn
      {identity, :ok} when identity != :anonymous ->
        ref = CriticalEventDispatcher.handler_ref(identity)
        CriticalEventDispatcher.mark_processed(event.event_id, ref)

      {identity, {:error, _reason}} when identity != :anonymous ->
        enqueue_critical_retry(event, identity, context)

      # Trigger: anonymous handlers (runtime-subscribed lambdas) have no identity
      # Why: can't serialize anonymous functions for Oban — no retry possible
      # Outcome: log and skip, same as normal event dispatch
      {_identity, {:error, _} = failure} ->
        log_dispatch_failure(event, [failure])

      _ ->
        :ok
    end)

    :ok
  end

  defp dispatch_normal(%DomainEvent{} = event, context) do
    case DomainEventBus.dispatch(context, event) do
      :ok ->
        :ok

      {:error, failures} ->
        log_dispatch_failure(event, failures)
        :ok
    end
  end

  defp enqueue_critical_retry(%DomainEvent{} = event, {module, function}, context) do
    handler_ref = CriticalEventDispatcher.handler_ref({module, function})

    args =
      CriticalEventSerializer.serialize(event)
      |> Map.merge(%{
        "handler" => handler_ref,
        "context" => inspect(context)
      })

    case Oban.insert(CriticalEventWorker.new(args)) do
      {:ok, _job} ->
        Logger.info(
          "Enqueued critical event retry: event_type=#{event.event_type} handler=#{handler_ref}",
          event_id: event.event_id,
          event_type: event.event_type,
          handler: handler_ref
        )

      {:error, reason} ->
        Logger.error(
          "Failed to enqueue critical event retry: event_type=#{event.event_type} handler=#{handler_ref}",
          event_id: event.event_id,
          reason: inspect(reason)
        )
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

  # Trigger: DomainEventBus returns error tuples in various shapes
  # Why: bus can produce {:error, reason}, {:error, {:handler_crashed, e}}, or bare terms
  # Outcome: normalizes all shapes to a flat {:error, reason}
  defp normalize_failure({:error, reason}), do: {:error, reason}
  defp normalize_failure(other), do: {:error, other}
end
