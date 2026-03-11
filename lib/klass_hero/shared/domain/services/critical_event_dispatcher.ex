defmodule KlassHero.Shared.Domain.Services.CriticalEventDispatcher do
  @moduledoc """
  Exactly-once dispatch for critical events.

  Owns the idempotency invariant: a given event-handler pair is processed at
  most once, regardless of how many delivery paths attempt it. Both the PubSub
  real-time path and the Oban durable path funnel through this module.

  Uses a `processed_events` table with composite key `{event_id, handler_ref}`
  and transactional insert + handler execution to guarantee atomicity.
  """

  alias KlassHero.Repo
  alias KlassHero.Shared.Adapters.Driven.Persistence.Schemas.ProcessedEvent

  @doc """
  Derives the canonical handler reference string from a `{module, function}` tuple.

  Format: `"Elixir.Module.Name:function_name"`

  Used as the `handler_ref` column value in the `processed_events` table and in
  Oban job args. Both delivery paths must produce the same string for the same
  handler to ensure idempotency deduplication works.
  """
  @spec handler_ref({module(), atom()}) :: String.t()
  def handler_ref({module, function}) when is_atom(module) and is_atom(function) do
    # Trigger: module atom needs canonical "Elixir.Module.Name" prefix
    # Why: inspect/1 strips the "Elixir." prefix in Elixir >= 1.3; Atom.to_string/1
    #      gives the raw atom string including the "Elixir." prefix, which is
    #      required for stable cross-path deduplication in processed_events table.
    # Outcome: both PubSub and Oban paths produce identical handler_ref strings
    "#{Atom.to_string(module)}:#{function}"
  end

  @doc """
  Reconstitutes a `{module, function}` tuple from a handler ref string.

  Inverse of `handler_ref/1`. Uses `String.to_existing_atom/1` — safe because
  handler modules are loaded at boot via the supervision tree.
  """
  @spec parse_handler_ref(String.t()) :: {module(), atom()}
  def parse_handler_ref(handler_ref_str) when is_binary(handler_ref_str) do
    case String.split(handler_ref_str, ":") do
      [module_str, function_str] ->
        {String.to_existing_atom(module_str), String.to_existing_atom(function_str)}

      _other ->
        raise ArgumentError,
              "Invalid handler_ref format: #{inspect(handler_ref_str)}. " <>
                "Expected \"Elixir.Module.Name:function_name\"."
    end
  end

  @doc """
  Executes a handler exactly once for a given event-handler pair.

  Uses a database transaction to atomically:
  1. Insert a `processed_events` row (ON CONFLICT DO NOTHING)
  2. If inserted (not a duplicate), run the handler function
  3. If handler succeeds, commit — row persists as proof of processing
  4. If handler fails or crashes, rollback — row removed, allowing retry

  Returns `:ok` if the handler ran successfully or was already processed.
  Returns `{:error, reason}` if the handler failed (row is rolled back).
  """
  @spec execute(String.t(), String.t(), (-> :ok | {:error, term()})) :: :ok | {:error, term()}
  def execute(event_id, handler_ref, handler_fn)
      when is_binary(event_id) and is_binary(handler_ref) and is_function(handler_fn, 0) do
    Repo.transaction(fn ->
      case insert_processed_event(event_id, handler_ref) do
        # Trigger: event-handler pair already in processed_events
        # Why: another delivery path (PubSub or earlier Oban attempt) already handled it
        # Outcome: skip handler, return :ok (idempotent no-op)
        :already_processed ->
          :ok

        # Trigger: row inserted — this is the first attempt for this pair
        # Why: handler must run inside the transaction so rollback removes the row on failure
        # Outcome: handler runs, success commits, failure rolls back
        :inserted ->
          run_handler(handler_fn)
      end
    end)
    |> unwrap_transaction_result()
  end

  @doc """
  Marks an event-handler pair as processed without running a handler.

  Used by `EventDispatchHelper` when a critical domain event's handler already
  succeeded synchronously via `DomainEventBus`. Inserts the `processed_events`
  row so any subsequent Oban retry is a no-op.

  Idempotent — calling twice with the same args is safe.
  """
  @spec mark_processed(String.t(), String.t()) :: :ok
  def mark_processed(event_id, handler_ref) when is_binary(event_id) and is_binary(handler_ref) do
    insert_processed_event(event_id, handler_ref)
    :ok
  end

  defp insert_processed_event(event_id, handler_ref) do
    now = DateTime.utc_now()

    result =
      Repo.insert_all(
        ProcessedEvent,
        [%{event_id: event_id, handler_ref: handler_ref, processed_at: now}],
        on_conflict: :nothing
      )

    case result do
      {1, _} -> :inserted
      {0, _} -> :already_processed
    end
  end

  defp run_handler(handler_fn) do
    case handler_fn.() do
      :ok -> :ok
      {:error, reason} -> Repo.rollback({:handler_failed, reason})
    end
  rescue
    error ->
      Repo.rollback({:handler_crashed, error})
  end

  defp unwrap_transaction_result({:ok, :ok}), do: :ok

  defp unwrap_transaction_result({:error, {:handler_failed, reason}}), do: {:error, reason}

  defp unwrap_transaction_result({:error, {:handler_crashed, error}}),
    do: {:error, {:handler_crashed, error}}
end
