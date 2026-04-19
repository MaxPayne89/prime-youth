defmodule KlassHeroWeb.Helpers.TaskHelpers do
  @moduledoc """
  Safe task result retrieval for LiveView mounts.

  Pairs with `Task.Supervisor.async_nolink/2` to safely yield results
  without crashing the calling LiveView on task failure or timeout.
  """

  require Logger

  @default_timeout 5_000

  @doc """
  Safely awaits a task result, returning `fallback` on crash or timeout.

  Expects a task spawned via `Task.Supervisor.async_nolink/2`. Uses
  `Task.yield/2` + `Task.shutdown/1` to retrieve the result without
  propagating EXIT signals.

  ## Options

    * `:timeout` - milliseconds to wait (default: #{@default_timeout})
    * `:label` - descriptive label for log messages (default: `"task"`)
  """
  def safe_await(task, fallback, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    label = Keyword.get(opts, :label, "task")

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} ->
        result

      {:exit, reason} ->
        Logger.error("[#{label}] Task crashed", reason: inspect(reason))
        fallback

      nil ->
        Logger.error("[#{label}] Task timed out after #{timeout}ms")
        fallback
    end
  end
end
