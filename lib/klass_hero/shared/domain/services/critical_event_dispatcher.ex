defmodule KlassHero.Shared.Domain.Services.CriticalEventDispatcher do
  @moduledoc """
  Exactly-once dispatch for critical events.

  Owns the idempotency invariant: a given event-handler pair is processed at
  most once, regardless of how many delivery paths attempt it. Both the PubSub
  real-time path and the Oban durable path funnel through this module.

  Uses a `processed_events` table with composite key `{event_id, handler_ref}`
  and transactional insert + handler execution to guarantee atomicity.
  """

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
end
