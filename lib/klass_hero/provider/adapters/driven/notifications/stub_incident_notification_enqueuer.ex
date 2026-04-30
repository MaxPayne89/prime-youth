defmodule KlassHero.Provider.Adapters.Driven.Notifications.StubIncidentNotificationEnqueuer do
  @moduledoc """
  Test stub for `ForEnqueuingIncidentNotifications`.

  Default mode is *passthrough* — delegates to `IncidentNotificationEnqueuer`
  so existing end-to-end tests (which rely on `Oban testing: :inline`)
  continue to enqueue and execute jobs as if the production adapter were
  wired directly.

  Tests that need to exercise the rollback path flip the mode for the
  current process via `set_failure_mode/1`. Because the command runs in
  the same process as the test, the process-dictionary flag is visible
  inside `Repo.transaction/1`.
  """

  @behaviour KlassHero.Provider.Domain.Ports.ForEnqueuingIncidentNotifications

  alias KlassHero.Provider.Adapters.Driven.Notifications.IncidentNotificationEnqueuer

  @mode_key :__incident_notification_enqueuer_mode__
  @calls_key :__incident_notification_enqueuer_calls__

  @impl true
  def enqueue(report) do
    record_call(report)

    case Process.get(@mode_key, :passthrough) do
      :passthrough -> IncidentNotificationEnqueuer.enqueue(report)
      {:fail, reason} -> {:error, reason}
    end
  end

  @doc """
  Forces the next `enqueue/1` calls in this process to return `{:error, reason}`.
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
  Returns the list of incident reports `enqueue/1` was called with, in order.
  """
  @spec calls() :: [struct()]
  def calls, do: Process.get(@calls_key, []) |> Enum.reverse()

  defp record_call(report) do
    Process.put(@calls_key, [report | Process.get(@calls_key, [])])
  end
end
