defmodule KlassHero.Provider.Adapters.Driven.Notifications.IncidentNotificationSchedulerTest do
  @moduledoc """
  Contract test for the production `ForSchedulingIncidentNotifications`
  adapter. Lives outside the `SubmitIncidentReport` test (which uses the
  passthrough stub) so the worker/queue/args contract is asserted against
  the real Oban call without an inline-mode side-effect.
  """

  use KlassHero.DataCase, async: true
  use Oban.Testing, repo: KlassHero.Repo

  alias KlassHero.Provider.Adapters.Driven.Notifications.IncidentNotificationScheduler
  alias KlassHero.Provider.Adapters.Driving.Workers.NotifyIncidentReportedWorker
  alias KlassHero.Provider.Domain.Models.IncidentReport
  alias KlassHero.Provider.Domain.Models.ProviderProfile

  describe "schedule/2" do
    test "enqueues NotifyIncidentReportedWorker with report id + owner email + business name" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        # Bypassing IncidentReport.new/1 + the persisting fixtures on purpose:
        # this is a contract test for the adapter, which only reads a few
        # fields off each struct. A real fixture would add DB writes and FK
        # setup that don't contribute to what this test asserts.
        report = struct(IncidentReport, id: Ecto.UUID.generate())

        profile =
          struct(ProviderProfile,
            id: Ecto.UUID.generate(),
            identity_id: Ecto.UUID.generate(),
            business_name: "Acme Adventures",
            business_owner_email: "owner@example.com"
          )

        assert {:ok, _job} = IncidentNotificationScheduler.schedule(report, profile)

        assert_enqueued(
          worker: NotifyIncidentReportedWorker,
          args: %{
            incident_report_id: report.id,
            business_owner_email: "owner@example.com",
            business_name: "Acme Adventures"
          },
          queue: :email
        )
      end)
    end
  end
end
