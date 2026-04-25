defmodule KlassHero.Provider.Adapters.Driving.Workers.NotifyIncidentReportedWorker do
  @moduledoc """
  Oban worker that delivers the incident-report email for a single report.

  Runs on the `:email` queue (concurrency 1) so Resend rate limits are
  respected globally. Delegates the actual orchestration to the
  `NotifyIncidentReported` use case.
  """

  use KlassHero.Shared.RateLimitedEmailWorker, queue: :email, max_attempts: 3

  alias KlassHero.Provider.Application.Commands.Incident.NotifyIncidentReported

  @impl true
  def execute(%Oban.Job{args: %{"incident_report_id" => id}}) when is_binary(id) do
    NotifyIncidentReported.execute(%{incident_report_id: id})
  end
end
