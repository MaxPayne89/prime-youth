defmodule KlassHero.Shared.Adapters.Driven.Workers.CriticalEventWorker do
  @moduledoc """
  Generic Oban worker for durable delivery of critical events.

  Deserializes the event from job args, reconstitutes the handler function,
  and dispatches through `CriticalEventDispatcher` for exactly-once execution.

  Used as a fallback when:
  - A critical domain event's handler failed during synchronous dispatch
  - A critical integration event needs durable delivery alongside PubSub
  """

  use Oban.Worker,
    queue: :critical_events,
    max_attempts: 3

  alias KlassHero.Shared.Adapters.Driven.Events.CriticalEventSerializer
  alias KlassHero.Shared.Domain.Services.CriticalEventDispatcher

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args, attempt: attempt, max_attempts: max_attempts}) do
    handler_ref_str = Map.fetch!(args, "handler")
    {module, function} = parse_handler_ref(handler_ref_str)
    event = CriticalEventSerializer.deserialize(args)

    result =
      CriticalEventDispatcher.execute(event.event_id, handler_ref_str, fn ->
        apply(module, function, [event])
      end)

    # Trigger: all retry attempts exhausted and handler still failing
    # Why: critical events that permanently fail need operator attention
    # Outcome: error-level log with full context for ErrorTracker alerting
    case result do
      {:error, reason} when attempt >= max_attempts ->
        Logger.error(
          "Critical event permanently failed after #{max_attempts} attempts: " <>
            "event_type=#{args["event_type"]} handler=#{handler_ref_str}",
          event_id: args["event_id"],
          event_type: args["event_type"],
          handler: handler_ref_str,
          reason: inspect(reason),
          attempt: attempt
        )

        result

      _ ->
        result
    end
  end

  # Trigger: handler ref stored as "Elixir.Module.Name:function" string
  # Why: Oban args are JSON — can't store module/function atoms directly
  # Outcome: reconstitute {module, function} tuple using existing atoms (safe
  #          because handler modules are loaded at boot via supervision tree)
  defp parse_handler_ref(handler_ref_str) do
    [module_str, function_str] = String.split(handler_ref_str, ":")
    {String.to_existing_atom(module_str), String.to_existing_atom(function_str)}
  end
end
