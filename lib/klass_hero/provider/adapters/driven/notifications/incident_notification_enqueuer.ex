defmodule KlassHero.Provider.Adapters.Driven.Notifications.IncidentNotificationEnqueuer do
  @moduledoc """
  Oban-backed adapter for `ForEnqueuingIncidentNotifications`.

  Inserts an `Oban.Job` for `NotifyIncidentReportedWorker` via the shared
  tracing-aware enqueue helper. Returns a tuple — never raises — so the
  caller's `Repo.transaction` can roll back on failure.

  The insert lives in the `oban_jobs` table, so a successful insert here
  is ACID-atomic with the calling transaction's other writes (report row).
  """

  @behaviour KlassHero.Provider.Domain.Ports.ForEnqueuingIncidentNotifications

  alias KlassHero.Provider.Adapters.Driving.Workers.NotifyIncidentReportedWorker
  alias KlassHero.Provider.Domain.Models.IncidentReport
  alias KlassHero.Shared.Tracing.ObanEnqueue

  @impl true
  def enqueue(%IncidentReport{id: id}) when is_binary(id) do
    ObanEnqueue.with_context(NotifyIncidentReportedWorker, %{incident_report_id: id})
  end
end
