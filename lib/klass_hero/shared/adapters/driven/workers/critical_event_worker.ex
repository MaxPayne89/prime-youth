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

  @doc """
  Inserts a critical event job and logs the outcome.

  Callers build the args map (serialized event + "handler" key); this function
  handles `Oban.insert/1` and consistent success/error logging.
  """
  @spec insert_job(map()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def insert_job(args) when is_map(args) do
    event_type = args["event_type"]
    handler = args["handler"]

    case Oban.insert(new(args)) do
      {:ok, _job} = ok ->
        Logger.debug("Enqueued critical event job: #{event_type} → #{handler}",
          event_id: args["event_id"],
          handler: handler
        )

        ok

      {:error, reason} = error ->
        Logger.error("Failed to enqueue critical event job: #{event_type} → #{handler}",
          event_id: args["event_id"],
          reason: inspect(reason)
        )

        error
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args, attempt: attempt, max_attempts: max_attempts}) do
    handler_ref_str = Map.fetch!(args, "handler")
    {module, function} = CriticalEventDispatcher.parse_handler_ref(handler_ref_str)
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
end
