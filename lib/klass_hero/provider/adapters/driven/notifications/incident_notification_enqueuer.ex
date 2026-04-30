defmodule KlassHero.Provider.Adapters.Driven.Notifications.IncidentNotificationEnqueuer do
  @moduledoc """
  Oban-backed adapter for `ForEnqueuingIncidentNotifications`.

  Builds the worker args (with tracing context propagated) and inserts an
  `Oban.Job` for `NotifyIncidentReportedWorker`. Returns a tuple — never
  raises — so the caller's `Repo.transaction` can roll back on failure.

  Insert lives in the `oban_jobs` table, so a successful insert here is
  ACID-atomic with the calling transaction's other writes (report row).
  """

  @behaviour KlassHero.Provider.Domain.Ports.ForEnqueuingIncidentNotifications

  alias KlassHero.Provider.Adapters.Driving.Workers.NotifyIncidentReportedWorker
  alias KlassHero.Provider.Domain.Models.IncidentReport
  alias KlassHero.Shared.Tracing.Context

  @impl true
  def enqueue(%IncidentReport{id: id}) when is_binary(id) do
    %{incident_report_id: id}
    |> Context.inject_into_args()
    |> NotifyIncidentReportedWorker.new()
    |> Oban.insert()
  end
end
