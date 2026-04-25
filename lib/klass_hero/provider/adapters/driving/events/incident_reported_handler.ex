defmodule KlassHero.Provider.Adapters.Driving.Events.IncidentReportedHandler do
  @moduledoc """
  Integration event handler for `:incident_reported`.

  Thin dispatcher that enqueues `NotifyIncidentReportedWorker` for each
  reported incident. Domain orchestration (self-report check, owner email
  resolution, photo signing) lives in the `NotifyIncidentReported` use case.
  """

  @behaviour KlassHero.Shared.Domain.Ports.Driving.ForHandlingIntegrationEvents

  alias KlassHero.Provider.Adapters.Driving.Workers.NotifyIncidentReportedWorker
  alias KlassHero.Shared.Domain.Events.IntegrationEvent
  alias KlassHero.Shared.Tracing.Context

  require Logger

  @impl true
  def subscribed_events, do: [:incident_reported]

  @impl true
  def handle_event(%IntegrationEvent{event_type: :incident_reported, entity_id: incident_id}) do
    args =
      %{incident_report_id: incident_id}
      |> Context.inject_into_args()

    args
    |> NotifyIncidentReportedWorker.new()
    |> Oban.insert()
    |> case do
      {:ok, _job} ->
        Logger.info("[IncidentReportedHandler] Enqueued incident notification",
          incident_report_id: incident_id
        )

        :ok

      {:error, reason} ->
        Logger.error("[IncidentReportedHandler] Failed to enqueue notification",
          incident_report_id: incident_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  def handle_event(_event), do: :ignore
end
