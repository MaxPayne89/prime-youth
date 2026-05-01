defmodule KlassHero.Provider.Adapters.Driven.Notifications.StubIncidentNotificationScheduler do
  @moduledoc """
  Test stub for `ForSchedulingIncidentNotifications`.

  Default mode is *passthrough* — delegates to `IncidentNotificationScheduler`
  so existing end-to-end tests (which rely on `Oban testing: :inline`)
  continue to enqueue and execute jobs as if the production adapter were
  wired directly.

  Tests that need to exercise the rollback path flip the mode for the
  current process via `set_failure_mode/1`. Because the command runs in
  the same process as the test, the process-dictionary flag is visible
  inside `Repo.transaction/1`.
  """

  @behaviour KlassHero.Provider.Domain.Ports.ForSchedulingIncidentNotifications

  alias KlassHero.Provider.Adapters.Driven.Notifications.IncidentNotificationScheduler

  @mode_key :__incident_notification_scheduler_mode__
  @calls_key :__incident_notification_scheduler_calls__

  @impl true
  def schedule(report, profile) do
    record_call({report, profile})

    case Process.get(@mode_key, :passthrough) do
      :passthrough -> IncidentNotificationScheduler.schedule(report, profile)
      {:fail, reason} -> {:error, reason}
    end
  end

  @doc """
  Forces the next `schedule/1` calls in this process to return `{:error, reason}`.
  """
  @spec set_failure_mode(term()) :: :ok
  def set_failure_mode(reason) do
    Process.put(@mode_key, {:fail, reason})
    :ok
  end

  @doc """
  Resets the stub to passthrough mode and clears recorded calls.
  """
  @spec reset() :: :ok
  def reset do
    Process.delete(@mode_key)
    Process.delete(@calls_key)
    :ok
  end

  @doc """
  Returns the list of `{report, profile}` tuples `schedule/2` was called with, in order.
  """
  @spec calls() :: [{struct(), struct()}]
  def calls, do: Process.get(@calls_key, []) |> Enum.reverse()

  defp record_call(call) do
    Process.put(@calls_key, [call | Process.get(@calls_key, [])])
  end
end
