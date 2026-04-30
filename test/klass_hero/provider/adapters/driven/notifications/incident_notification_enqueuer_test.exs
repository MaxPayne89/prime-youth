defmodule KlassHero.Provider.Adapters.Driven.Notifications.IncidentNotificationEnqueuerTest do
  @moduledoc """
  Contract test for the production `ForEnqueuingIncidentNotifications`
  adapter. Lives outside the `SubmitIncidentReport` test (which uses the
  passthrough stub) so the worker/queue/args contract is asserted against
  the real Oban call without an inline-mode side-effect.
  """

  use KlassHero.DataCase, async: true
  use Oban.Testing, repo: KlassHero.Repo

  alias KlassHero.Provider.Adapters.Driven.Notifications.IncidentNotificationEnqueuer
  alias KlassHero.Provider.Adapters.Driving.Workers.NotifyIncidentReportedWorker
  alias KlassHero.Provider.Domain.Models.IncidentReport

  describe "enqueue/1" do
    test "schedules NotifyIncidentReportedWorker on the :email queue with the report id" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        # Bypassing IncidentReport.new/1 + the persisting `incident_report_fixture/1`
        # on purpose: this is a contract test for the adapter, which only reads
        # `id`. A real fixture would add a DB write and a provider/program setup
        # for foreign keys — neither contributes to what this test asserts.
        report = struct(IncidentReport, id: Ecto.UUID.generate())

        assert {:ok, _job} = IncidentNotificationEnqueuer.enqueue(report)

        assert_enqueued(
          worker: NotifyIncidentReportedWorker,
          args: %{incident_report_id: report.id},
          queue: :email
        )
      end)
    end
  end
end
