defmodule KlassHero.Provider.Adapters.Driving.Events.IncidentReportedHandlerTest do
  @moduledoc """
  Tests for IncidentReportedHandler — a thin dispatcher that enqueues an
  Oban job for each `:incident_reported` integration event. Asserts on the
  enqueued job using `Oban.Testing.assert_enqueued/1` under manual mode.
  """

  use KlassHero.DataCase, async: true
  use Oban.Testing, repo: KlassHero.Repo

  alias KlassHero.Provider.Adapters.Driving.Events.IncidentReportedHandler
  alias KlassHero.Provider.Adapters.Driving.Workers.NotifyIncidentReportedWorker
  alias KlassHero.Provider.Domain.Events.ProviderIntegrationEvents
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  describe "subscribed_events/0" do
    test "subscribes only to :incident_reported" do
      assert IncidentReportedHandler.subscribed_events() == [:incident_reported]
    end
  end

  describe "handle_event/1 — :incident_reported" do
    test "enqueues NotifyIncidentReportedWorker with the report id" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        incident_id = Ecto.UUID.generate()
        event = ProviderIntegrationEvents.incident_reported(incident_id)

        assert :ok = IncidentReportedHandler.handle_event(event)

        assert_enqueued(
          worker: NotifyIncidentReportedWorker,
          args: %{incident_report_id: incident_id},
          queue: :email
        )
      end)
    end
  end

  describe "handle_event/1 — unrelated events" do
    test "ignores events of other types" do
      event =
        IntegrationEvent.new(:something_else, :provider, :incident_report, "id-1", %{})

      assert :ignore = IncidentReportedHandler.handle_event(event)
    end
  end
end
