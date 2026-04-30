defmodule KlassHero.Provider.Adapters.Driven.Notifications.IncidentNotificationScheduler do
  @moduledoc """
  Oban-backed adapter for `ForSchedulingIncidentNotifications`.

  Inserts an `Oban.Job` for `NotifyIncidentReportedWorker` via the shared
  tracing-aware enqueue helper. Returns a tuple — never raises — so the
  caller's `Repo.transaction` can roll back on failure.

  The insert lives in the `oban_jobs` table, so a successful insert here
  is ACID-atomic with the calling transaction's other writes (report row).
  """

  @behaviour KlassHero.Provider.Domain.Ports.ForSchedulingIncidentNotifications

  alias KlassHero.Provider.Adapters.Driving.Workers.NotifyIncidentReportedWorker
  alias KlassHero.Provider.Domain.Models.IncidentReport
  alias KlassHero.Shared.Tracing.ObanEnqueue

  @impl true
  def schedule(%IncidentReport{id: id}) when is_binary(id) do
    ObanEnqueue.with_context(NotifyIncidentReportedWorker, %{incident_report_id: id})
  end
end
