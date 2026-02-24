defmodule KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.EnqueueInviteEmailsTest do
  use KlassHero.DataCase, async: true
  use Oban.Testing, repo: KlassHero.Repo

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.EnqueueInviteEmails

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepository

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.BulkEnrollmentInviteSchema
  alias KlassHero.Enrollment.Adapters.Driven.Workers.SendInviteEmailWorker
  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Repo

  defp create_pending_invites(_context) do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id, title: "Dance Class")

    rows = [
      %{
        program_id: program.id,
        provider_id: provider.id,
        child_first_name: "Emma",
        child_last_name: "Schmidt",
        child_date_of_birth: ~D[2016-03-15],
        guardian_email: "parent@example.com",
        guardian_first_name: "Hans"
      },
      %{
        program_id: program.id,
        provider_id: provider.id,
        child_first_name: "Liam",
        child_last_name: "Mueller",
        child_date_of_birth: ~D[2017-01-10],
        guardian_email: "other@example.com",
        guardian_first_name: "Maria"
      }
    ]

    {:ok, 2} = BulkEnrollmentInviteRepository.create_batch(rows)
    %{provider: provider, program: program}
  end

  describe "handle/1" do
    setup :create_pending_invites

    test "enqueues Oban jobs for each pending invite", %{
      provider: provider,
      program: program
    } do
      Oban.Testing.with_testing_mode(:manual, fn ->
        event = EnrollmentEvents.bulk_invites_imported(provider.id, [program.id], 2)
        assert :ok = EnqueueInviteEmails.handle(event)

        invites = Repo.all(BulkEnrollmentInviteSchema)

        Enum.each(invites, fn inv ->
          assert_enqueued(
            worker: SendInviteEmailWorker,
            args: %{invite_id: inv.id, program_name: "Dance Class"}
          )
        end)
      end)
    end

    test "assigns tokens and enqueues jobs", %{provider: provider, program: program} do
      Oban.Testing.with_testing_mode(:manual, fn ->
        event = EnrollmentEvents.bulk_invites_imported(provider.id, [program.id], 2)
        assert :ok = EnqueueInviteEmails.handle(event)

        invites = Repo.all(BulkEnrollmentInviteSchema)
        assert Enum.all?(invites, fn inv -> inv.invite_token != nil end)
        assert length(Enum.uniq_by(invites, & &1.invite_token)) == 2
      end)
    end

    test "does nothing when no pending invites exist", %{
      provider: provider,
      program: program
    } do
      Repo.update_all(BulkEnrollmentInviteSchema, set: [status: "failed", error_details: "test"])

      Oban.Testing.with_testing_mode(:manual, fn ->
        event = EnrollmentEvents.bulk_invites_imported(provider.id, [program.id], 0)
        assert :ok = EnqueueInviteEmails.handle(event)

        refute_enqueued(worker: SendInviteEmailWorker)
      end)
    end

    test "skips invites that already have tokens", %{provider: provider, program: program} do
      invite = Repo.all(BulkEnrollmentInviteSchema) |> hd()
      invite |> Ecto.Changeset.change(%{invite_token: "pre-existing"}) |> Repo.update!()

      Oban.Testing.with_testing_mode(:manual, fn ->
        event = EnrollmentEvents.bulk_invites_imported(provider.id, [program.id], 2)
        assert :ok = EnqueueInviteEmails.handle(event)

        # Trigger: one invite already had a token
        # Why: list_pending_without_token filters out already-tokenized invites
        # Outcome: only the untokenized invite gets a job
        all_enqueued = all_enqueued(worker: SendInviteEmailWorker)
        assert length(all_enqueued) == 1
      end)
    end
  end
end
